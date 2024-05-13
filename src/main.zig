const std = @import("std");
const Scanner = @import("Scanner.zig");

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

    const file = std.fs.cwd().readFileAlloc(allocator, getFirstArg(allocator), 1000) catch @panic("could not read file");
    defer allocator.free(file);

    var scanner = Scanner.init(file, allocator);
    defer scanner.deinit();

    const tokens = scanner.scanTokens();
    for (tokens.items) |value| {
        switch (value) {
            .new_line => std.debug.print("\n", .{}),
            else => std.debug.print("{s} ", .{@tagName(value)}),
        }
    }
}
