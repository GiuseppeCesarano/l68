const std = @import("std");
const Lexer = @import("Lexer.zig");

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

    var scanner = Lexer.init(file, allocator);
    defer scanner.deinit();
    const tokens = scanner.scanTokens();

    std.debug.print("{}\n", .{tokens.len});
    // std.debug.print("{}\n", .{@as(f32, @floatFromInt(tokens.len)) / @as(f32, @floatFromInt(file_stats.size))});
    // const print = std.debug.print;
    // var last_line: u32 = 0;
    // for (tokens) |token_info| {
    //     if (last_line != token_info.line) {
    //         last_line = token_info.line;
    //         print("\n", .{});
    //     }
    //     switch (token_info.token) {
    //         .label => print(" {s}", .{token_info.token.label}),
    //         .immediate => print(" #{}", .{token_info.token.immediate}),
    //         .immediate_label => print(" #{s}", .{token_info.token.immediate_label}),
    //         .absolute => print(" {}", .{token_info.token.absolute}),
    //         .char => print(" '{c}'", .{token_info.token.char}),
    //         .string => print(" '{s}'", .{token_info.token.string}),
    //         .comma => print(",", .{}),
    //         .left_parentheses => print(" (", .{}),
    //         .right_parentheses => print(" )", .{}),
    //         .plus => print(" +", .{}),
    //         .minus => print(" -", .{}),
    //         .multiply => print(" *", .{}),
    //         .divide => print(" /", .{}),
    //         .byte_size => print(".b", .{}),
    //         .word_size => print(".w", .{}),
    //         .long_size => print(".l", .{}),
    //         .data_register => print(" d{}", .{token_info.token.data_register}),
    //         .address_register => print(" a{}", .{token_info.token.address_register}),
    //         else => print(" {s}", .{@tagName(token_info.token)}),
    //     }
    // }
}
