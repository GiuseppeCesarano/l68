const std = @import("std");

pub fn create(T: type, size: comptime_int) type {
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
    var queue = create(u8, 20).init();

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
