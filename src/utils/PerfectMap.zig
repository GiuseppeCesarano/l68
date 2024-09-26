const std = @import("std");

pub fn create(comptime m_seed: u32, comptime size: usize, comptime key_value_pairs: anytype) type {
    return struct {
        const map_generic = map_generics(key_value_pairs);
        const seed = m_seed;
        const map = map_generic.generate(m_seed, size, key_value_pairs) orelse @compileError("Seed and size used do not generate a valid map");

        pub fn get(str: []const u8) ?map_generic.Value {
            if (str.len < 2 or str.len > 7) return null;

            const encoded_key = map_generic.encode(str);
            const entry = map[map_generic.hash(encoded_key, seed, map.len)];

            return if (entry.key == encoded_key) entry.value else null;
        }
    };
}

pub fn createBruteforcing(comptime kvs: anytype) type {
    const map_generic = map_generics(kvs);

    @setEvalBranchQuota(std.math.maxInt(u32));

    comptime var size = 1;
    inline while (size < 36) : (size += 1) {
        comptime var seed = 1500;
        inline while (seed < 3000) : (seed += 1) {
            if (map_generic.generate(seed, kvs.len * size, kvs)) |_| {
                return create(seed, kvs.len * size, kvs);
            }
        }
    }

    @compileError("can not create a valid seed and size pair");
}

fn map_generics(comptime kvs_: anytype) type {
    validateKvs(kvs_);
    return struct {
        pub const Value = @TypeOf(kvs_[0][1]);
        pub const Key = std.meta.Int(.unsigned, 64 - @bitSizeOf(@TypeOf(kvs_[0][1])));
        pub const Entry = struct {
            key: Key,
            value: Value,
        };

        pub fn generate(comptime seed: u32, comptime size: usize, comptime kvs: anytype) ?[size]Entry {
            var data = [_]Entry{.{ .key = 0, .value = undefined }} ** size;

            for (kvs) |kv| {
                @setEvalBranchQuota(std.math.maxInt(u32));
                const len = std.mem.indexOfScalar(u8, &kv[0], 0) orelse kv[0].len;
                const encoded_key = encode(kv[0][0..len]);
                const i = hash(encoded_key, seed, size);
                if (data[i].key != 0) {
                    break;
                }
                data[i] = Entry{ .key = encoded_key, .value = kv[1] };
            } else return data;

            return null;
        }

        pub fn encode(str: []const u8) Key {
            std.debug.assert(str.len > 1 and str.len < 8);

            const is_odd = str.len % 2 == 1;
            var value: Key = if (is_odd) @intCast(str[0] | 0x20) else 0;
            var i: usize = @intFromBool(is_odd);

            while (i != str.len) : (i += 2) {
                //TODO: use a @ptrCast to []const u16 when zig will supports size changing casting.
                const wchar = @as(u16, str[i]) << 8 | str[i + 1];
                value = (value << 16) | (wchar | 0x2020);
            }

            return value;
        }

        pub inline fn hash(input: Key, comptime seed: u32, comptime len: usize) usize {
            @setEvalBranchQuota(std.math.maxInt(u32));
            return std.hash.Murmur3_32.hashUint64WithSeed(input, seed) % len;
        }
    };
}

fn validateKvs(kvs: anytype) void {
    if (isKVTypeInvalid(@TypeOf(kvs))) @compileError("key_value_pairs must be of type: []struct{[]const u8, ValueType}");
    if (kvs.len == 0) @compileError("key_value_pairs is empty");
    if (isKVTooBig(kvs)) @compileError("key.len + @sizeOf(Value) must be <= 8 bytes");
}

fn isKVTooBig(kvs: anytype) bool {
    var max_key_len = 0;
    for (kvs) |kv| {
        if (kv[0].len > max_key_len) {
            max_key_len = kv[0].len;
        }
    }

    return max_key_len + @sizeOf(@TypeOf(kvs[0][1])) > @sizeOf(u64);
}

fn isKVTypeInvalid(Kvs: type) bool {
    switch (@typeInfo(Kvs)) {
        .array => {},
        else => return true,
    }

    const Child = std.meta.Child(Kvs);

    switch (@typeInfo(Child)) {
        .@"struct" => |info| {
            switch (@typeInfo(info.fields[0].type)) {
                .array => {},
                else => return true,
            }

            if (!info.is_tuple) {
                return true;
            }
        },
        else => return true,
    }

    return false;
}
