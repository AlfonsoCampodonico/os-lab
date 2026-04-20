const std = @import("std");

const Starter = struct {
    name: []const u8,
    source: []const u8,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const starters = [_]Starter{
        .{ .name = "process_explorer", .source = "starter/lab1-process-explorer/process_explorer.zig" },
        .{ .name = "counter_lab", .source = "starter/lab2-counter-lab/counter_lab.zig" },
        .{ .name = "memory_probe", .source = "starter/lab3-memory-probe/memory_probe.zig" },
        .{ .name = "tinysh", .source = "starter/lab4-tiny-shell/tinysh.zig" },
    };

    for (starters) |starter| {
        const exe = b.addExecutable(.{
            .name = starter.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(starter.source),
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });

        b.installArtifact(exe);
    }
}
