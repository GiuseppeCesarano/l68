const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const fmt = b.addModule("fmt", .{
        .root_source_file = b.path(("src/utils/fmt.zig")),
        .target = target,
        .optimize = optimize,
    });

    const compactStringView = b.addModule("CompactStringView", .{
        .root_source_file = b.path(("src/utils/CompactStringView.zig")),
        .target = target,
        .optimize = optimize,
    });

    const swapQueue = b.addModule("SwapQueue", .{
        .root_source_file = b.path(("src/utils/SwapQueue.zig")),
        .target = target,
        .optimize = optimize,
    });

    const token = b.addModule("Token", .{
        .root_source_file = b.path(("src/core/Token.zig")),
        .target = target,
        .optimize = optimize,
    });
    token.addImport("CompactStringView", compactStringView);

    const lexer = b.addModule("Lexer", .{
        .root_source_file = b.path(("src/core/Lexer.zig")),
        .target = target,
        .optimize = optimize,
    });
    lexer.addImport("Token", token);
    lexer.addImport("fmt", fmt);
    lexer.addImport("SwapQueue", swapQueue);

    const exe = b.addExecutable(.{
        .name = "l68",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("Lexer", lexer);
    exe.root_module.addImport("Token", token);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/helpers.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
