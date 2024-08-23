const std = @import("std");
const Lexer = @import("Lexer");
const Parser = @import("Parser");

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

    var scanner_thread = try std.Thread.spawn(.{}, Lexer.scan, .{&scanner});

    var parser = Parser.init(&scanner);

    parser.parse();

    scanner_thread.join();
}
