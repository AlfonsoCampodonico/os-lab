const builtin = @import("builtin");
const std = @import("std");

const c = @cImport({
    @cInclude("fcntl.h");
    @cInclude("sys/time.h");
    @cInclude("sys/mman.h");
    @cInclude("sys/stat.h");
    @cInclude("unistd.h");
});

fn writeStdout(comptime fmt: []const u8, args: anytype) !void {
    var buffer: [512]u8 = undefined;
    const text = try std.fmt.bufPrint(&buffer, fmt, args);
    if (c.write(c.STDOUT_FILENO, text.ptr, text.len) < 0) {
        return error.WriteFailed;
    }
}

fn writeStdoutRaw(bytes: []const u8) !void {
    if (c.write(c.STDOUT_FILENO, bytes.ptr, bytes.len) < 0) {
        return error.WriteFailed;
    }
}

fn writeStderr(comptime fmt: []const u8, args: anytype) void {
    var buffer: [256]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, fmt, args) catch return;
    _ = c.write(c.STDERR_FILENO, text.ptr, text.len);
}

fn nowMs() f64 {
    var tv: c.timeval = undefined;
    _ = c.gettimeofday(&tv, null);
    return @as(f64, @floatFromInt(tv.tv_sec)) * 1000.0 +
        @as(f64, @floatFromInt(tv.tv_usec)) / 1000.0;
}

fn printMaps() !void {
    if (builtin.os.tag == .linux) {
        var file = try std.fs.openFileAbsolute("/proc/self/maps", .{});
        defer file.close();

        var buffer: [1024]u8 = undefined;
        while (true) {
            const read_amount = try file.read(&buffer);
            if (read_amount == 0) break;
            try writeStdoutRaw(buffer[0..read_amount]);
        }
    } else {
        var stack_value: i32 = 42;
        const heap_value = try std.heap.page_allocator.alloc(u8, 16);
        defer std.heap.page_allocator.free(heap_value);

        try writeStdout("maps mode is Linux-specific on this starter platform.\n", .{});
        try writeStdout("stack address: 0x{x}\n", .{@intFromPtr(&stack_value)});
        try writeStdout("heap address: 0x{x}\n", .{@intFromPtr(heap_value.ptr)});
    }
}

fn runTouch(megabytes: usize, pattern: []const u8) !void {
    const total_bytes = megabytes * 1024 * 1024;
    const stride = 4096;

    if (total_bytes == 0) {
        writeStderr("megabytes must be positive\n", .{});
        return error.InvalidMegabytes;
    }

    if (!std.mem.eql(u8, pattern, "sequential") and !std.mem.eql(u8, pattern, "random")) {
        writeStderr("pattern must be either sequential or random\n", .{});
        return error.InvalidPattern;
    }

    const buffer = try std.heap.page_allocator.alloc(u8, total_bytes);
    defer std.heap.page_allocator.free(buffer);
    @memset(buffer, 0);

    var steps = total_bytes / stride;
    if (steps == 0) steps = 1;

    const started_ms = nowMs();
    if (std.mem.eql(u8, pattern, "random")) {
        var state: u32 = 0x12345678;
        var index: usize = 0;
        while (index < steps) : (index += 1) {
            state = state *% 1664525 +% 1013904223;
            const page_index = @as(usize, state) % steps;
            buffer[page_index * stride] +%= 1;
        }
    } else {
        var index: usize = 0;
        while (index < steps) : (index += 1) {
            buffer[index * stride] +%= 1;
        }
    }

    const elapsed_ms = nowMs() - started_ms;
    try writeStdout(
        "touch pattern={s} megabytes={d} pages={d} elapsed_ms={d:.3}\n",
        .{
            pattern,
            megabytes,
            steps,
            elapsed_ms,
        },
    );
}

fn runMmapDemo() !void {
    var template = "/tmp/os-lab-mmap-demo-XXXXXX".*;
    const length: usize = 4096;
    const message = "mapped hello\n";

    const fd = c.mkstemp(&template);
    if (fd < 0) {
        return error.CreateTempFailed;
    }
    defer _ = c.close(fd);

    _ = c.unlink(&template);
    if (c.ftruncate(fd, @intCast(length)) != 0) {
        return error.TruncateFailed;
    }

    const raw_ptr = c.mmap(null, length, c.PROT_READ | c.PROT_WRITE, c.MAP_SHARED, fd, 0);
    if (raw_ptr == c.MAP_FAILED) {
        return error.MapFailed;
    }
    defer _ = c.munmap(raw_ptr, length);

    const mapping: [*]u8 = @ptrCast(@alignCast(raw_ptr));
    @memcpy(mapping[0..message.len], message);
    try writeStdoutRaw(mapping[0..message.len]);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args.deinit();

    _ = args.next();
    const mode = if (args.next()) |arg| arg else "maps";
    if (std.mem.eql(u8, mode, "maps")) {
        try printMaps();
        return;
    }

    if (std.mem.eql(u8, mode, "touch")) {
        const megabytes = if (args.next()) |arg| try std.fmt.parseInt(usize, arg, 10) else 8;
        const pattern = if (args.next()) |arg| arg else "sequential";
        try runTouch(megabytes, pattern);
        return;
    }

    if (std.mem.eql(u8, mode, "mmap-demo")) {
        try runMmapDemo();
        return;
    }

    writeStderr(
        "usage: {s} [maps|touch <mb> <sequential|random>|mmap-demo]\n",
        .{"memory_probe"},
    );
    return error.InvalidMode;
}
