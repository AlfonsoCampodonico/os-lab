const std = @import("std");

const c = @cImport({
    @cInclude("fcntl.h");
    @cInclude("stdio.h");
    @cInclude("sys/types.h");
    @cInclude("sys/wait.h");
    @cInclude("unistd.h");
});

const ParsedCommand = struct {
    allocator: std.mem.Allocator,
    z_args: std.array_list.Managed([:0]u8),
    c_argv: std.array_list.Managed(?[*:0]u8),

    fn init(allocator: std.mem.Allocator) ParsedCommand {
        return .{
            .allocator = allocator,
            .z_args = std.array_list.Managed([:0]u8).init(allocator),
            .c_argv = std.array_list.Managed(?[*:0]u8).init(allocator),
        };
    }

    fn deinit(self: *ParsedCommand) void {
        for (self.z_args.items) |arg| {
            self.allocator.free(arg);
        }
        self.z_args.deinit();
        self.c_argv.deinit();
    }
};

fn writeStdout(comptime fmt: []const u8, args: anytype) !void {
    var buffer: [512]u8 = undefined;
    const text = try std.fmt.bufPrint(&buffer, fmt, args);
    if (c.write(c.STDOUT_FILENO, text.ptr, text.len) < 0) {
        return error.WriteFailed;
    }
}

fn writeStderr(comptime fmt: []const u8, args: anytype) void {
    var buffer: [256]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, fmt, args) catch return;
    _ = c.write(c.STDERR_FILENO, text.ptr, text.len);
}

fn parseCommand(allocator: std.mem.Allocator, command_text: []const u8) !ParsedCommand {
    var parsed = ParsedCommand.init(allocator);
    errdefer parsed.deinit();

    var tokenizer = std.mem.tokenizeAny(u8, command_text, " \t");
    while (tokenizer.next()) |token| {
        const z_arg = try allocator.dupeZ(u8, token);
        try parsed.z_args.append(z_arg);
        try parsed.c_argv.append(z_arg.ptr);
    }
    try parsed.c_argv.append(null);

    return parsed;
}

fn waitForPid(pid: c.pid_t) !void {
    var status: c_int = 0;
    if (c.waitpid(pid, &status, 0) < 0) {
        return error.WaitFailed;
    }
}

fn runSimpleCommand(allocator: std.mem.Allocator, command_text: []const u8) !void {
    var redirect_iter = std.mem.splitScalar(u8, command_text, '>');
    const command_part = std.mem.trim(u8, redirect_iter.first(), " \t");
    const maybe_output = redirect_iter.next();

    if (redirect_iter.next() != null) {
        writeStderr("parse error: only one output redirection is supported\n", .{});
        return error.ParseError;
    }

    var output_path: ?[]const u8 = null;
    if (maybe_output) |output| {
        const trimmed_output = std.mem.trim(u8, output, " \t");
        if (trimmed_output.len == 0) {
            writeStderr("parse error: output redirection requires a file name\n", .{});
            return error.ParseError;
        }
        output_path = trimmed_output;
    }

    var parsed = try parseCommand(allocator, command_part);
    defer parsed.deinit();

    if (parsed.z_args.items.len == 0) {
        return;
    }

    const pid = c.fork();
    if (pid < 0) {
        return error.ForkFailed;
    }

    if (pid == 0) {
        if (output_path) |path| {
            const z_path = allocator.dupeZ(u8, path) catch c._exit(1);
            defer allocator.free(z_path);

            const fd = c.open(z_path.ptr, c.O_CREAT | c.O_TRUNC | c.O_WRONLY, @as(c_uint, 0o644));
            if (fd < 0) {
                c.perror("open");
                c._exit(1);
            }

            if (c.dup2(fd, c.STDOUT_FILENO) < 0) {
                c.perror("dup2");
                c._exit(1);
            }
            _ = c.close(fd);
        }

        _ = c.execvp(parsed.c_argv.items[0].?, @ptrCast(parsed.c_argv.items.ptr));
        c.perror("execvp");
        c._exit(127);
    }

    try waitForPid(pid);
}

fn runPipeCommand(allocator: std.mem.Allocator, left_text: []const u8, right_text: []const u8) !void {
    const left_part = std.mem.trim(u8, left_text, " \t");
    const right_part = std.mem.trim(u8, right_text, " \t");

    var left = try parseCommand(allocator, left_part);
    defer left.deinit();

    var right = try parseCommand(allocator, right_part);
    defer right.deinit();

    if (left.z_args.items.len == 0 or right.z_args.items.len == 0) {
        writeStderr("parse error: pipeline requires commands on both sides\n", .{});
        return error.ParseError;
    }

    var pipefd: [2]c_int = undefined;
    if (c.pipe(&pipefd) != 0) {
        return error.PipeFailed;
    }

    const left_pid = c.fork();
    if (left_pid < 0) {
        _ = c.close(pipefd[0]);
        _ = c.close(pipefd[1]);
        return error.ForkFailed;
    }

    if (left_pid == 0) {
        _ = c.dup2(pipefd[1], c.STDOUT_FILENO);
        _ = c.close(pipefd[0]);
        _ = c.close(pipefd[1]);
        _ = c.execvp(left.c_argv.items[0].?, @ptrCast(left.c_argv.items.ptr));
        c.perror("execvp");
        c._exit(127);
    }

    const right_pid = c.fork();
    if (right_pid < 0) {
        _ = c.close(pipefd[0]);
        _ = c.close(pipefd[1]);
        return error.ForkFailed;
    }

    if (right_pid == 0) {
        _ = c.dup2(pipefd[0], c.STDIN_FILENO);
        _ = c.close(pipefd[0]);
        _ = c.close(pipefd[1]);
        _ = c.execvp(right.c_argv.items[0].?, @ptrCast(right.c_argv.items.ptr));
        c.perror("execvp");
        c._exit(127);
    }

    _ = c.close(pipefd[0]);
    _ = c.close(pipefd[1]);

    try waitForPid(left_pid);
    try waitForPid(right_pid);
}

fn printHelp() !void {
    try writeStdout("tinysh commands:\n", .{});
    try writeStdout("  help\n", .{});
    try writeStdout("  quit\n", .{});
    try writeStdout("  external commands\n", .{});
    try writeStdout("  output redirection with >\n", .{});
    try writeStdout("  single pipeline with |\n", .{});
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var shell_status: u8 = 0;
    var line_buffer: [4096]u8 = undefined;

    while (true) {
        try writeStdout("tinysh> ", .{});

        const raw_line = c.fgets(@ptrCast(&line_buffer), @intCast(line_buffer.len), c.stdin());
        if (raw_line == null) break;

        const line = std.mem.trim(u8, std.mem.span(raw_line), " \t\r\n");
        if (line.len == 0) continue;

        if (std.mem.eql(u8, line, "quit")) break;
        if (std.mem.eql(u8, line, "help")) {
            try printHelp();
            continue;
        }

        if (std.mem.indexOfScalar(u8, line, '|')) |pipe_index| {
            if (runPipeCommand(allocator, line[0..pipe_index], line[pipe_index + 1 ..])) |_| {} else |_| {
                shell_status = 1;
            }
            continue;
        }

        if (runSimpleCommand(allocator, line)) |_| {} else |_| {
            shell_status = 1;
        }
    }

    std.process.exit(shell_status);
}
