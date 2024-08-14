const std = @import("std");
const Lexer = @import("Lexer");

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

    const print = std.debug.print;
    while (scanner.tokens.consume()) |token| {
        switch (token.type) {
            .label => print(" {s}", .{"PLACEHOLDER"}),
            .immediate => print(" #{}", .{token.data.Number}),
            .immediate_label => print(" #{s}", .{"PLACEHOLDER2"}),
            .absolute => print(" {}", .{token.data.Number}),
            .char => print(" '{c}'", .{token.data.Char}),
            .string => print(" '{s}'", .{"PLACEHOLDER3"}),
            .comma => print(",", .{}),
            .B => print(".b", .{}),
            .W => print(".w", .{}),
            .L => print(".l", .{}),
            .Dn => print(" d{}", .{token.data.Register}),
            .An => print(" a{}", .{token.data.Register}),
            .new_line => print("\n", .{}),
            .@"(An)" => print(" (a{}) ", .{token.data.Register}),
            .@"(An)+" => print(" (a{})+ ", .{token.data.Register}),
            .@"-(An)" => print(" -(a{}) ", .{token.data.Register}),
            .@"(d,An)" => print(" ({}, a{}) ", .{ token.data.SimpleAddressing.displacement, token.data.SimpleAddressing.register }),
            .@"(d,An,Xi)" => print(" ({}, a{}, {c}{}) ", .{
                token.data.ComplexAddressing.displacement,
                token.data.ComplexAddressing.address_register,
                if (token.data.ComplexAddressing.index_type == .data) @as(u8, 'd') else @as(u8, 'a'),
                token.data.ComplexAddressing.index_register,
            }),
            else => print(" {s}", .{@tagName(token.type)}),
        }
    } else |_| {}
}
