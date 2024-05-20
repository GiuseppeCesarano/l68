const std = @import("std");
const err_writer = std.io.getStdErr().writer();
const This = @This();

//TODO: Needs hard refactoring

text: []const u8,
new_line_locations: std.ArrayList(u32),

pub fn init(text: []const u8, allocator: std.mem.Allocator, new_lines_hint: usize) This {
    var value: This = .{ .text = text, .new_line_locations = std.ArrayList(u32).initCapacity(allocator, new_lines_hint) catch @panic("no") };
    value.fillNewLines();
    return value;
}

pub fn deinit(this: This) void {
    this.new_line_locations.deinit();
}

fn fillNewLines(this: *This) void {
    for (this.text, 0..) |c, i| {
        if (c == '\n') {
            this.new_line_locations.append(@intCast(i)) catch @panic("no");
        }
    }
}

pub fn reportUnexpectedToken(this: This, unknown_token_location: u32) void {
    const line_number, const col = this.findLineNumberAndCol(unknown_token_location);
    const line = this.getLine(line_number);
    err_writer.print("error: unknown token, at line: {}, col: {}\n", .{ line_number + 1, col + 1 }) catch return;
    printNoTab(err_writer.any(), line) catch return;
    err_writer.writeByte('\n') catch return;
    err_writer.writeByteNTimes(' ', col) catch return;
    err_writer.writeByte('^') catch return;
    err_writer.writeByteNTimes('~', tokenLenght(line[col + 1 ..])) catch return;
    err_writer.writeByte('\n') catch return;
}

fn findLineNumberAndCol(this: This, unknown_token_location: u32) struct { u32, u32 } {
    var line_number: u32 = 0;
    while (this.new_line_locations.items[line_number] < unknown_token_location) : (line_number += 1) {}

    return .{ line_number, unknown_token_location - this.new_line_locations.items[line_number - 1] - 1 };
}

fn printNoTab(writer: std.io.AnyWriter, line: []const u8) !void {
    for (line) |c| {
        try writer.writeByte(if (c != '\t') c else ' ');
    }
}

fn getLine(this: This, line_number: u32) []const u8 {
    return this.text[this.new_line_locations.items[line_number - 1]..this.new_line_locations.items[line_number]];
}

fn tokenLenght(line: []const u8) usize {
    for (line, 0..) |c, i| {
        if (!std.ascii.isAlphanumeric(c) and c != '$' and c != '#') {
            return i;
        }
    }
    return line.len;
}
