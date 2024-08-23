//! std.fmt.parseInt like functions can parse asimtool's prefixs
//! the signed function must be used with unsigned types they do the base complement as asimtool does.

const std = @import("std");
pub const Error = std.fmt.ParseIntError;

pub inline fn parse(comptime T: type, str: []const u8) Error!T {
    return if (@typeInfo(T).Int.signedness == .unsigned) parseUnsigned(T, str) else parseSigned(T, str);
}

pub inline fn parseSigned(comptime T: type, str: []const u8) Error!T {
    if (@typeInfo(T).Int.signedness != .signed) @compileError("T must be signed");
    if (str.len == 0) return Error.InvalidCharacter;
    const is_negative = str[0] == '-';

    const uv = try parseUnsigned(makeUnsigned(T), str[@intFromBool(is_negative)..]);
    const v = std.math.cast(T, uv) orelse return Error.Overflow;

    return if (is_negative) -v else v;
}

pub inline fn parseUnsigned(comptime T: type, str: []const u8) Error!T {
    if (@typeInfo(T).Int.signedness != .unsigned) @compileError("T must be unsigned");
    if (str.len == 0) return Error.InvalidCharacter;
    return switch (str[0]) {
        '%' => try std.fmt.parseUnsigned(T, str[1..], 2),
        '@' => try std.fmt.parseUnsigned(T, str[1..], 8),
        '$' => try std.fmt.parseUnsigned(T, str[1..], 16),
        '0'...'9' => std.fmt.parseUnsigned(T, str, 10),
        else => return Error.InvalidCharacter,
    };
}

fn makeUnsigned(comptime T: type) type {
    var t = @typeInfo(T);
    t.Int.signedness = .unsigned;

    return @Type(t);
}
