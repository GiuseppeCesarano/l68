const std = @import("std");

pub fn create(T: type, size: comptime_int) type {
    return struct {
        const This = @This();
        const Buffer = struct { data: [size]T = undefined, used: usize };

        buffers: [2]Buffer = .{ .{ .used = 0 }, .{ .used = size } },
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

        pub fn produce(this: *This, elm: T) void {
            this.waitBuffersSwap();
            const buffer = this.getBuffer(.producer);

            buffer.data[buffer.used] = elm;
            buffer.used += 1;

            if (buffer.used == buffer.data.len) {
                this.is_ready_for_swap.store(true, .release);
            }
        }

        pub fn consume(this: *This) !T {
            var buffer = this.getBuffer(.consumer);

            if (buffer.used == buffer.data.len - this.empty) {
                if (!this.is_ready_for_swap.load(.acquire) and this.production_ended.load(.acquire)) return Errors.OverConsumption;
                this.swapBuffers();
                buffer = this.getBuffer(.consumer);
            }

            buffer.used += 1;

            return buffer.data[buffer.used - 1];
        }

        /// If this function is not called the last `number_of_produced % size` elements will not be made
        /// aviable to the consumer untill `number_of_produced % size == 0`
        pub fn flushProduction(this: *This) void {
            const buffer = this.getBuffer(.producer);
            if (buffer.used != 0) this.is_ready_for_swap.store(true, .release);
        }

        pub fn endProduction(this: *This) void {
            this.flushProduction();
            this.production_ended.store(true, .release);
        }

        inline fn waitBuffersSwap(this: *This) void {
            while (this.is_ready_for_swap.load(.acquire)) {
                std.atomic.spinLoopHint();
            }
        }

        inline fn swapBuffers(this: *This) void {
            while (!this.is_ready_for_swap.load(.acquire)) {
                std.atomic.spinLoopHint();
            }

            this.index ^= 1;

            const buffer = this.getBuffer(.consumer);
            this.empty = buffer.data.len - buffer.used;

            this.buffers[0].used = 0;
            this.buffers[1].used = 0;

            this.is_ready_for_swap.store(false, .release);
        }

        inline fn getBuffer(this: *This, comptime p_or_c: enum { producer, consumer }) *Buffer {
            return &this.buffers[this.index ^ @intFromBool(p_or_c == .consumer)];
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
