const std = @import("std");
const err_writer = std.io.getStdErr().writer();

pub fn unexpectedToken(line: []const u8, line_num: usize, column: usize) void {
    err_writer.print("error: unknown token, at line: {}, column: {}\n", .{ line_num + 1, column + 1 }) catch return;
    printNoTab(err_writer.any(), line) catch return;
    err_writer.writeByte('\n') catch return;
    err_writer.writeByteNTimes(' ', column) catch return;
    err_writer.writeByte('^') catch return;
    err_writer.writeByteNTimes('~', tokenLenght(line[column + 1 ..])) catch return;
    err_writer.writeByte('\n') catch return;
}

fn printNoTab(writer: std.io.AnyWriter, text: []const u8) !void {
    for (text) |char| {
        try writer.writeByte(if (char != '\t') char else ' ');
    }
}

fn tokenLenght(line: []const u8) usize {
    for (line, 0..) |char, i| {
        if (!std.ascii.isAlphanumeric(char) and char != '$' and char != '#') {
            return i;
        }
    }
    return line.len;
}
