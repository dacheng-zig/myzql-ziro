const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 3rd modules
    const xev = b.dependency("libxev", .{}).module("xev");
    const ziro = b.dependency("ziro", .{}).module("ziro");
    const myzql = b.dependency("myzql", .{}).module("myzql");

    const exe = b.addExecutable(.{
        .name = "myzql_ziro",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "xev", .module = xev },
                .{ .name = "ziro", .module = ziro },
                .{ .name = "myzql", .module = myzql },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
