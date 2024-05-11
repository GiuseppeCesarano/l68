const std = @import("std");
const err_writer = std.io.getStdErr().writer();

pub fn unexpectedToken(line: []const u8, line_num: usize, column: usize) void {
    err_writer.print(
        \\error: unknown token '{c}', at line: {}, column: {}
        \\{s}
        \\
    , .{
        line[column],
        line_num + 1,
        column + 1,
        line,
    }) catch return;
    const leading_tabs = std.mem.count(u8, line[0..column], "\t");
    err_writer.writeByteNTimes('\t', leading_tabs) catch return;
    err_writer.writeByteNTimes(' ', column - leading_tabs) catch return;
    err_writer.writeByte('^') catch return;
    err_writer.writeByteNTimes('~', wordLenght(line[column + 1 ..])) catch return;
    err_writer.writeByte('\n') catch return;
}

fn wordLenght(line: []const u8) usize {
    for (line, 0..) |char, i| {
        if (!std.ascii.isAlphanumeric(char)) {
            return i;
        }
    }
    return line.len;
}
