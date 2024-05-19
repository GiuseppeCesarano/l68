const std = @import("std");
const Scanner = @import("Scanner.zig");
const Reporter = @import("Reporter.zig");

fn getFirstArg(allocator: std.mem.Allocator) [:0]const u8 {
    var args_it = std.process.argsWithAllocator(allocator) catch @panic("error: Could not allocate memory to parse arguments.");
    defer args_it.deinit();

    _ = args_it.skip();

    return args_it.next() orelse @panic("error: a file path is needed as first argument.");
}

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path = getFirstArg(allocator);
    const file_stats = std.fs.cwd().statFile(path) catch @panic("could not read file stats");

    const file = std.fs.cwd().readFileAlloc(allocator, path, file_stats.size) catch @panic("could not read file");
    defer allocator.free(file);

    var scanner = Scanner.init(file, allocator);
    defer scanner.deinit();

    _, const errors = scanner.scanTokens();

    const reporter = Reporter.init(file, allocator, scanner.line_count);
    defer reporter.deinit();

    if (errors) |errs| {
        for (errs) |err| {
            reporter.reportUnexpectedToken(err);
        }
    }
}
