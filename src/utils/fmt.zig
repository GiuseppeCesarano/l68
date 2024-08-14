//! std.fmt.parseInt like functions can parse asimtool's prefixs
//TODO: maybe change
//! the signed function must be used with unsigned types they do the base complement as asimtool does.

const std = @import("std");

pub inline fn parseSigned(comptime T: type, str: []const u8) !T {
    if (@typeInfo(T).Int.signedness != .unsigned) @compileError("Passed type must be always unsigned, even for signed rappresentation.");
    if (str.len == 0) return std.fmt.ParseIntError.InvalidCharacter;
    const is_negative = str[0] == '-';

    const value = try parseUnsigned(T, str[@intFromBool(is_negative)..]);

    return if (is_negative) (~value) + 1 else value;
}

pub inline fn parseUnsigned(comptime T: type, str: []const u8) !T {
    if (@typeInfo(T).Int.signedness != .unsigned) @compileError("Passed type must be always unsigned");
    if (str.len == 0) return std.fmt.ParseIntError.InvalidCharacter;
    return switch (str[0]) {
        '%' => try std.fmt.parseUnsigned(T, str[1..], 2),
        '@' => try std.fmt.parseUnsigned(T, str[1..], 8),
        '$' => try std.fmt.parseUnsigned(T, str[1..], 16),
        '0'...'9' => std.fmt.parseUnsigned(T, str, 10),
        else => return std.fmt.ParseIntError.InvalidCharacter,
    };
}
