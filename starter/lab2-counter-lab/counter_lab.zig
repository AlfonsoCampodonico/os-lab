const std = @import("std");
const c = @cImport({
    @cInclude("sys/time.h");
    @cInclude("unistd.h");
});

const Mode = enum {
    race,
    mutex,
};

const SharedState = struct {
    counter: i64 = 0,
    iterations_per_thread: i64,
    mode: Mode,
    mutex: std.atomic.Mutex = .unlocked,
};

fn writeStdout(comptime fmt: []const u8, args: anytype) !void {
    var buffer: [256]u8 = undefined;
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

fn nowMs() f64 {
    var tv: c.timeval = undefined;
    _ = c.gettimeofday(&tv, null);
    return @as(f64, @floatFromInt(tv.tv_sec)) * 1000.0 +
        @as(f64, @floatFromInt(tv.tv_usec)) / 1000.0;
}

fn lockMutex(mutex: *std.atomic.Mutex) void {
    while (!mutex.tryLock()) {
        std.Thread.yield() catch {};
    }
}

fn workerMain(state: *SharedState) void {
    var iteration: i64 = 0;
    while (iteration < state.iterations_per_thread) : (iteration += 1) {
        switch (state.mode) {
            .mutex => {
                lockMutex(&state.mutex);
                state.counter += 1;
                state.mutex.unlock();
            },
            .race => {
                const snapshot = state.counter;
                if (@mod(iteration, 100) == 0) {
                    std.Thread.yield() catch {};
                }
                state.counter = snapshot + 1;
            },
        }
    }
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args.deinit();

    var mode: Mode = .race;
    var thread_count: usize = 4;
    var iterations_per_thread: i64 = 100_000;

    _ = args.next();
    if (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "mutex")) {
            mode = .mutex;
        } else if (!std.mem.eql(u8, arg, "race")) {
            writeStderr("mode must be either race or mutex\n", .{});
            return error.InvalidMode;
        }
    }

    if (args.next()) |arg| thread_count = try std.fmt.parseInt(usize, arg, 10);
    if (args.next()) |arg| iterations_per_thread = try std.fmt.parseInt(i64, arg, 10);

    if (thread_count == 0 or thread_count > 128) {
        writeStderr("thread_count must be between 1 and 128\n", .{});
        return error.InvalidThreadCount;
    }

    var state = SharedState{
        .iterations_per_thread = iterations_per_thread,
        .mode = mode,
    };

    const threads = try allocator.alloc(std.Thread, thread_count);
    defer allocator.free(threads);

    const started_ms = nowMs();
    for (threads, 0..) |*thread, index| {
        _ = index;
        thread.* = try std.Thread.spawn(.{}, workerMain, .{&state});
    }

    for (threads) |thread| {
        thread.join();
    }

    const elapsed_ms = nowMs() - started_ms;
    const expected: i64 = @as(i64, @intCast(thread_count)) * iterations_per_thread;
    const mode_name = switch (mode) {
        .race => "race",
        .mutex => "mutex",
    };

    try writeStdout(
        "mode={s} threads={d} iterations={d} expected={d} actual={d} elapsed_ms={d:.3}\n",
        .{
            mode_name,
            thread_count,
            iterations_per_thread,
            expected,
            state.counter,
            elapsed_ms,
        },
    );
}
