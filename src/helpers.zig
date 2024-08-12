//! This module provides a variety of miscellaneous structures
//! and functions utilized throughout the entirety of the codebase.

const std = @import("std");

/// A 32 bit sized type designed to be a compact alternative to `[] const u8`
/// The offset must be referenced to a known string.
/// This type only supports strings <= 4MiB
/// The max lenght for for the string view is 1024
pub const CompactStringView = packed struct {
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
};

test "CompactStringView size test" {
    try std.testing.expectEqual(@bitSizeOf(CompactStringView), 32);
}

test "CompactStringView slice" {
    const s = "01234";
    const sw = CompactStringView{ .offset = 2, .len = 2 };

    const slice = sw.toSlice(s);
    try std.testing.expectEqual(slice.len, 2);
    try std.testing.expectEqual(slice[0], '2');
    try std.testing.expectEqual(slice[1], '3');

    const sliceOffset = sw.toSliceWithOffset(s, 1);
    try std.testing.expectEqual(sliceOffset.len, 2);
    try std.testing.expectEqual(sliceOffset[0], '3');
    try std.testing.expectEqual(sliceOffset[1], '4');
}

/// std.fmt.parseInt like functions, but they use u32 and can parse asimtool's prefixs
/// the signed function returns u32 but does the base complement as asimtool does.
pub const fmt = struct {
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
};

pub fn SwapQueue(T: type, size: comptime_int) type {
    return struct {
        const This = @This();

        array: [2]struct { data: [size]T = undefined, used: usize } = .{ .{ .used = 0 }, .{ .used = size } },
        empty: usize = 0,
        index: u1 = 0,
        is_ready_for_swap: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
        production_ended: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

        pub const Errors = error{
            OverConsumption,
        };

        pub fn init() This {
            return This{};
        }

        /// If this function is not called the last `number_of_produced % size` elements will not be made
        /// aviable to the consumer untill `number_of_produced % size == 0`
        pub fn flushProduction(this: *This) void {
            const array = this.getArray(.producer);
            if (array.used != 0) this.is_ready_for_swap.store(true, .release);
        }

        inline fn getArray(this: *This, comptime p_or_c: enum { producer, consumer }) *std.meta.Child(@TypeOf(this.array)) {
            return &this.array[this.index ^ @intFromBool(p_or_c == .consumer)];
        }

        pub fn endProduction(this: *This) void {
            this.flushProduction();
            this.production_ended.store(true, .release);
        }

        pub fn addOne(this: *This) *T {
            var array = this.getArray(.producer);

            if (array.used == array.data.len) {
                this.waitSwap();
                array = this.getArray(.producer);
            }

            const position = &array.data[array.used];
            array.used += 1;

            return position;
        }

        pub fn produce(this: *This, elm: T) void {
            this.addOne().* = elm;
        }

        inline fn waitSwap(this: *This) void {
            this.is_ready_for_swap.store(true, .monotonic);
            while (this.is_ready_for_swap.load(.acquire)) {
                std.atomic.spinLoopHint();
            }
        }

        pub fn consume(this: *This) !T {
            var array = this.getArray(.consumer);

            if (array.used == array.data.len - this.empty) {
                if (!this.is_ready_for_swap.load(.acquire) and this.production_ended.load(.acquire)) return Errors.OverConsumption;
                this.swap();
                array = this.getArray(.consumer);
            }

            array.used += 1;

            return array.data[array.used - 1];
        }

        inline fn swap(this: *This) void {
            while (!this.is_ready_for_swap.load(.acquire)) {
                std.atomic.spinLoopHint();
            }

            this.index ^= 1;

            const array = this.getArray(.consumer);
            this.empty = array.data.len - array.used;

            this.array[0].used = 0;
            this.array[1].used = 0;

            this.is_ready_for_swap.store(false, .release);
        }
    };
}

fn testProduce(T: type, q: *T) void {
    for (0..std.math.maxInt(u8)) |v| {
        q.produce(@intCast(v));
    }
    q.flushProduction();
}

test "Queue" {
    var queue = SwapQueue(u8, 20).init();

    for (0..100) |_| {
        const t = try std.Thread.spawn(.{}, testProduce, .{ @TypeOf(queue), &queue });
        for (0..std.math.maxInt(u8)) |v| {
            try std.testing.expectEqual(v, try queue.consume());
        }
        t.join();
    }

    queue.endProduction();
    try std.testing.expectError(@TypeOf(queue).Errors.OverConsumption, queue.consume());
}
