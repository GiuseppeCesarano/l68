//! A 24 bit sized type designed to be a compact alternative to `[] const u8`
//! The offset must be referenced to a known string.

const std = @import("std");

pub const StringView = packed struct {
    offset: u16,
    len: u8,

    pub fn toSlice(this: @This(), str: []const u8) []const u8 {
        std.debug.assert(this.offset <= str.len);
        std.debug.assert(this.offset + this.len <= str.len);

        return str[this.offset .. this.offset + this.len];
    }

    pub fn toSliceWithOffset(this: @This(), str: []const u8, offset: usize) []const u8 {
        std.debug.assert(this.offset + offset <= str.len);
        std.debug.assert(this.offset + offset + this.len <= str.len);

        return str[this.offset + offset .. this.offset + offset + this.len];
    }

    test "CompactStringView size test" {
        try std.testing.expectEqual(@bitSizeOf(@This()), 32);
    }

    test "CompactStringView slice" {
        const t = std.testing;

        const s = "01234";
        const sw = @This(){ .offset = 2, .len = 2 };

        const slice = sw.toSlice(s);
        try t.expectEqual(slice.len, 2);
        try t.expectEqual(slice[0], '2');
        try t.expectEqual(slice[1], '3');

        const sliceOffset = sw.toSliceWithOffset(s, 1);
        try t.expectEqual(sliceOffset.len, 2);
        try t.expectEqual(sliceOffset[0], '3');
        try t.expectEqual(sliceOffset[1], '4');
    }

    test "CompactStringView's size" {
        try std.testing.expect(@bitSizeOf(@This()) == 24);
    }
};
