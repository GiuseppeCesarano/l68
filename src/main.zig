const std = @import("std");
const Lexer = @import("Lexer.zig");

fn getFirstArg(allocator: std.mem.Allocator) [:0]const u8 {
    var args_it = std.process.argsWithAllocator(allocator) catch @panic("error: Could not allocate memory to parse arguments.");
    defer args_it.deinit();

    _ = args_it.skip();

    return args_it.next() orelse @panic("error: a file path is needed as first argument.");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile(getFirstArg(allocator), .{ .mode = .read_only });
    defer file.close();
    const file_stat = try file.stat();
    const file_content = try std.posix.mmap(null, file_stat.size, std.posix.PROT.READ, .{ .TYPE = .PRIVATE, .NONBLOCK = true }, file.handle, 0);

    var scanner = Lexer.init(file_content, allocator);
    defer scanner.deinit();
    const tokens = scanner.scan();

    std.debug.print("{}\n", .{tokens.len});
    // std.debug.print("{}\n", .{@as(f32, @floatFromInt(tokens.len)) / @as(f32, @floatFromInt(file_stats.size))});
    // const print = std.debug.print;
    // var last_line: u32 = 0;
    // for (tokens) |token| {
    //     if (last_line != token.location.line) {
    //         last_line = token.location.line;
    //         print("\n", .{});
    //     }
    //     switch (token.type) {
    //         .label => print(" {s}", .{"PLACEHOLDER"}),
    //         .immediate => print(" #{}", .{token.data.number}),
    //         .immediate_label => print(" #{s}", .{"PLACEHOLDER2"}),
    //         .absolute => print(" {}", .{token.data.number}),
    //         .char => print(" '{c}'", .{token.data.byte}),
    //         .string => print(" '{s}'", .{"PLACEHOLDER3"}),
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
    //         .data_register => print(" d{}", .{token.data.byte}),
    //         .address_register => print(" a{}", .{token.data.byte}),
    //         else => print(" {s}", .{@tagName(token.type)}),
    //     }
    // }
}
