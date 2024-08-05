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

    var scanner = Lexer.init(file_content);
    defer scanner.deinit();

    _ = try std.Thread.spawn(.{}, Lexer.scan, .{&scanner});

    // var i: usize = 0;
    // while (scanner.tokens.consume()) |_| {
    //     i += 1;
    // } else |_| {}

    // std.debug.print("{}\n", .{i});
    // std.debug.print("{}\n", .{@as(f64, @floatFromInt(tokens.len)) / @as(f64, @floatFromInt(file_content.len))});
    const print = std.debug.print;
    while (scanner.tokens.consume()) |token| {
        switch (token.type) {
            .label => print(" {s}", .{"PLACEHOLDER"}),
            .immediate => print(" #{}", .{token.data.number}),
            .immediate_label => print(" #{s}", .{"PLACEHOLDER2"}),
            .absolute => print(" {}", .{token.data.number}),
            .char => print(" '{c}'", .{token.data.byte}),
            .string => print(" '{s}'", .{"PLACEHOLDER3"}),
            .comma => print(",", .{}),
            .left_parentheses => print(" (", .{}),
            .right_parentheses => print(" )", .{}),
            .plus => print(" +", .{}),
            .minus => print(" -", .{}),
            .multiply => print(" *", .{}),
            .divide => print(" /", .{}),
            .byte_size => print(".b", .{}),
            .word_size => print(".w", .{}),
            .long_size => print(".l", .{}),
            .data_register => print(" d{}", .{token.data.byte}),
            .address_register => print(" a{}", .{token.data.byte}),
            .new_line => print("\n", .{}),
            else => print(" {s}", .{@tagName(token.type)}),
        }
    } else |_| {}
}
