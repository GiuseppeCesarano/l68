const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const fmt = b.addModule("fmt", .{
        .root_source_file = b.path(("src/utils/fmt.zig")),
        .target = target,
        .optimize = optimize,
    });

    const compact = b.addModule("compact", .{
        .root_source_file = b.path(("src/utils/compact.zig")),
        .target = target,
        .optimize = optimize,
    });

    const swap_queue = b.addModule("SwapQueue", .{
        .root_source_file = b.path(("src/utils/SwapQueue.zig")),
        .target = target,
        .optimize = optimize,
    });

    const perfect_map = b.addModule("PerfectMap", .{
        .root_source_file = b.path(("src/utils/PerfectMap.zig")),
        .target = target,
        .optimize = optimize,
    });

    const token = b.addModule("token", .{
        .root_source_file = b.path(("src/core/token.zig")),
        .target = target,
        .optimize = optimize,
    });
    token.addImport("compact", compact);

    const lexer = b.addModule("Lexer", .{
        .root_source_file = b.path(("src/core/Lexer.zig")),
        .target = target,
        .optimize = optimize,
    });
    lexer.addImport("token", token);
    lexer.addImport("fmt", fmt);
    lexer.addImport("SwapQueue", swap_queue);
    lexer.addImport("PerfectMap", perfect_map);

    const parser = b.addModule("Parser", .{
        .root_source_file = b.path(("src/core/Parser.zig")),
        .target = target,
        .optimize = optimize,
    });
    parser.addImport("token", token);
    parser.addImport("Lexer", lexer);

    const exe = b.addExecutable(.{
        .name = "l68",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("token", token);
    exe.root_module.addImport("Lexer", lexer);
    exe.root_module.addImport("Parser", parser);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const compact_test = b.addTest(.{
        .root_source_file = b.path("src/utils/compact.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_compact_test = b.addRunArtifact(compact_test);

    const fmt_test = b.addTest(.{
        .root_source_file = b.path("src/utils/fmt.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_fmt_test = b.addRunArtifact(fmt_test);

    const swapQueue_test = b.addTest(.{
        .root_source_file = b.path("src/utils/SwapQueue.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_swapQueue_test = b.addRunArtifact(swapQueue_test);

    const token_test = b.addTest(.{
        .root_source_file = b.path("src/core/token.zig"),
        .target = target,
        .optimize = optimize,
    });
    token_test.root_module.addImport("compact", compact);
    const run_token_test = b.addRunArtifact(token_test);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_compact_test.step);
    test_step.dependOn(&run_fmt_test.step);
    test_step.dependOn(&run_swapQueue_test.step);
    test_step.dependOn(&run_token_test.step);
}
