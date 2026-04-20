const builtin = @import("builtin");
const std = @import("std");

const c = @cImport({
    @cInclude("signal.h");
    @cInclude("sys/types.h");
    @cInclude("sys/wait.h");
    @cInclude("unistd.h");
});

var stop_requested: c.sig_atomic_t = 0;

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

fn handleSignal(signal_number: c_int) callconv(.c) void {
    _ = signal_number;
    stop_requested = 1;
}

fn installSignalHandlers() !void {
    _ = c.signal(c.SIGINT, handleSignal);
    _ = c.signal(c.SIGTERM, handleSignal);
}

fn computeExitCode(worker_id: i32, base: i32) u8 {
    return @intCast(@mod(base + worker_id * 3, 100));
}

fn showRuntimeHint(pid: c.pid_t) !void {
    if (builtin.os.tag == .linux) {
        var path_buffer: [64]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buffer, "/proc/{d}/status", .{pid});
        var file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();

        var line_buffer: [256]u8 = undefined;
        const amount = try file.read(&line_buffer);
        if (amount > 0) {
            const line = line_buffer[0..amount];
            const end = std.mem.indexOfScalar(u8, line, '\n') orelse line.len;
            try writeStdout("[parent] proc hint for pid={d}: {s}\n", .{ pid, line[0..end] });
        }
    } else {
        try writeStdout(
            "[parent] runtime hint for pid={d}: /proc is unavailable on this platform\n",
            .{pid},
        );
    }
}

fn runChildWorker(worker_id: i32, base: i32) noreturn {
    var line_buffer: [160]u8 = undefined;
    const exit_code = computeExitCode(worker_id, base);
    const line = std.fmt.bufPrint(
        &line_buffer,
        "[child] worker={d} pid={d} ppid={d} exit_code={d}\n",
        .{ worker_id, c.getpid(), c.getppid(), exit_code },
    ) catch unreachable;

    _ = c.write(c.STDOUT_FILENO, line.ptr, line.len);
    _ = c.usleep(100_000);
    c._exit(exit_code);
}

fn spawnWorker(worker_id: i32, base: i32) !c.pid_t {
    const pid = c.fork();
    if (pid < 0) {
        return error.ForkFailed;
    }

    if (pid == 0) {
        runChildWorker(worker_id, base);
    }

    return pid;
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args.deinit();

    var worker_count: i32 = 3;
    var base: i32 = 5;

    _ = args.next();
    if (args.next()) |arg| worker_count = try std.fmt.parseInt(i32, arg, 10);
    if (args.next()) |arg| base = try std.fmt.parseInt(i32, arg, 10);

    if (worker_count <= 0 or worker_count > 32) {
        writeStderr("worker_count must be between 1 and 32\n", .{});
        return error.InvalidWorkerCount;
    }

    try installSignalHandlers();

    const worker_pids = try allocator.alloc(c.pid_t, @intCast(worker_count));
    defer allocator.free(worker_pids);

    try writeStdout(
        "[parent] pid={d} launching {d} workers with base={d}\n",
        .{ c.getpid(), worker_count, base },
    );

    var launched: usize = 0;
    var worker_id: i32 = 0;
    while (worker_id < worker_count) : (worker_id += 1) {
        if (stop_requested != 0) {
            try writeStdout("[parent] stop requested, not launching worker {d}\n", .{worker_id});
            break;
        }

        const pid = try spawnWorker(worker_id, base);
        worker_pids[launched] = pid;
        launched += 1;

        try writeStdout("[parent] launched worker={d} pid={d}\n", .{ worker_id, pid });
        try showRuntimeHint(pid);
    }

    var index: usize = 0;
    while (index < launched) : (index += 1) {
        var status: c_int = 0;
        const pid = c.waitpid(worker_pids[index], &status, 0);
        if (pid < 0) {
            return error.WaitPidFailed;
        }

        if (c.WIFEXITED(status)) {
            try writeStdout("[parent] pid={d} exited status={d}\n", .{ pid, c.WEXITSTATUS(status) });
        } else if (c.WIFSIGNALED(status)) {
            try writeStdout(
                "[parent] pid={d} terminated by signal={d}\n",
                .{ pid, c.WTERMSIG(status) },
            );
        }
    }
}
