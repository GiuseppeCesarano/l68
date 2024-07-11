//! This module provides a variety of miscellaneous structures
//! and functions utilized throughout the entirety of the codebase.

const std = @import("std");

/// A 32 bit sized type designed to be a compact alternative to `[] const u8`
/// The offset must be referenced to a known string.
/// This type only supports strings <= 4MiB
/// The max lenght for for the string view is 1024
pub const CompactStringView = packed struct {
    offset: u22,
    len: u10,

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
    pub inline fn parseSigned(str: []const u8) !u32 {
        const is_negative = str[0] == '-';

        const value = try parseUnsigned(str[@intFromBool(is_negative)..]);

        return if (is_negative) (~value) + 1 else value;
    }

    pub inline fn parseUnsigned(str: []const u8) !u32 {
        return switch (str[0]) {
            '%' => try std.fmt.parseUnsigned(u32, str[1..], 2),
            '@' => try std.fmt.parseUnsigned(u32, str[1..], 8),
            '$' => try std.fmt.parseUnsigned(u32, str[1..], 16),
            '0'...'9' => std.fmt.parseUnsigned(u32, str, 10),
            else => return std.fmt.ParseIntError.InvalidCharacter,
        };
    }
};

//TODO COMPLETE WITH CONDITIONAL VARIABLE TO STOP THE SPINWAIT AFTHER A BIT
pub fn Queue(T: type, size: comptime_int) type {
    return struct {
        const This = @This();

        array: [2]struct { data: [size]T = undefined, used: usize } = .{ .{ .used = 0 }, .{ .used = size } },
        empty: usize = 0,
        indexes: packed struct { producer: u1 = 0, consumer: u1 = 1 } = .{},
        is_consumer_done: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),

        pub fn int() This {
            return This{};
        }

        /// Forces a swap of the arrays allowing the consumer to access the produced data even if used < data.len
        /// The swap waits for the consumer to consume all the remaining data.
        pub fn endProductionBatch(this: *This) void {
            this.swap();
        }

        pub fn produce(this: *This, elm: T) void {
            var array = this.getArray(.producer);

            if (array.used == array.data.len) {
                this.swap();
                array = this.getArray(.producer);
            }

            array.data[array.used] = elm;
            array.used += 1;
        }

        fn getArray(this: *This, comptime p_or_c: enum { producer, consumer }) *std.meta.Child(@TypeOf(this.array)) {
            return if (p_or_c == .producer) &this.array[this.indexes.producer] else &this.array[this.indexes.consumer];
        }

        inline fn swap(this: *This) void {
            while (!this.is_consumer_done.load(.acquire)) {
                std.time.sleep(500);
            }

            const array = this.getArray(.producer);
            this.empty = array.data.len - array.used;

            this.indexes.producer ^= 1;
            this.indexes.consumer ^= 1;
            this.array[0].used = 0;
            this.array[1].used = 0;

            this.is_consumer_done.store(false, .release);
        }

        pub fn consume(this: *This) T {
            var array = this.getArray(.consumer);

            if (array.used == array.data.len - this.empty) {
                this.waitSwap();
                array = this.getArray(.consumer);
            }

            const r = array.data[array.used];
            array.used += 1;
            return r;
        }

        inline fn waitSwap(this: *This) void {
            this.is_consumer_done.store(true, .release);
            while (this.is_consumer_done.load(.acquire)) {
                std.time.sleep(500);
            }
        }
    };
}

fn testProduce(q: *Queue(u8, 20)) void {
    var random = std.Random.Pcg.init(@intCast(std.time.timestamp()));
    for (0..std.math.maxInt(u8)) |v| {
        std.time.sleep(random.random().int(u64) % 2000);
        q.produce(@intCast(v));
    }
    q.endProductionBatch();
}

test "Queue" {
    var queue = Queue(u8, 20).int();

    for (0..3) |_| {
        const t = try std.Thread.spawn(.{}, testProduce, .{&queue});
        for (0..std.math.maxInt(u8)) |v| {
            try std.testing.expectEqual(v, queue.consume());
        }
        t.join();
    }
}
