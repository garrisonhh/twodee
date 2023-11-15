const std = @import("std");
const fs = std.fs;
const Build = std.Build;

const project_name = "twodee";

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // module
    const mod = b.addModule(project_name, .{
        .source_file = .{ .path = "src/mod.zig" },
    });

    // hot reloading exe
    const exe = b.addExecutable(.{
        .name = project_name,
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    addLibs(exe);

    b.installArtifact(exe);

    // runner
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(&exe.step);
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "run the app");
    run_step.dependOn(&run_cmd.step);

    // example
    const example = b.addSharedLibrary(.{
        .name = "example",
        .root_source_file = .{ .path = "example/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    addLibs(example);
    example.addModule(project_name, mod);

    const example_cmd = b.addInstallArtifact(example, .{});
    const example_step = b.step("example", "build the example");
    example_step.dependOn(&example_cmd.step);

    // example runner
    const run_ex_cmd = b.addRunArtifact(exe);
    run_ex_cmd.step.dependOn(&exe.step);
    run_ex_cmd.step.dependOn(&example.step);
    run_ex_cmd.addArtifactArg(example);

    const run_ex_step = b.step("run-example", "run the example with the app");
    run_ex_step.dependOn(&run_ex_cmd.step);
}

fn addLibs(com: *Build.Step.Compile) void {
    com.linkLibC();
    com.linkSystemLibrary2("SDL2", .{});
    com.linkSystemLibrary2("epoxy", .{});
}
