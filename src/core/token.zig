const std = @import("std");
const StringView = @import("compact").StringView;

pub const Data = packed union {
    Number: u32,
    Register: u3,
    Char: u8,
    SimpleAddressing: packed struct { register: u3, displacement: i16 },
    ComplexAddressing: packed struct {
        address_register: u3,
        displacement: i16,
        index_type: enum(u1) { data, address },
        index_register: u3,
    },
};

pub const Type = enum(u8) {
    // Literals
    label,
    immediate,
    immediate_label,
    absolute,
    char,
    string,

    // Single charchater tokens
    comma,
    new_line,

    // Dual charchater tokens
    B,
    W,
    L,
    Dn,
    An,

    @"(An)",
    @"(An)+",
    @"-(An)",
    @"(d,An)",
    @"(d,An,Xi)",

    // mnemonics (must be ketp sequential)
    // zig fmt: off
    abcd, add, adda, addi, addq, @"and", andi, asl, asr,
    bcc, bchg, bclr, bra, bset, bsr, btst,
    chk, clr,
    cmp, cmpa, cmpi, cmpm,
    dbcc, dc, dcb, divs, ds,
    end, eor, eori, equ, exg, ext,
    illegal,
    jmp, jsr, 
    lea, link, lsl, lsr,
    move, movea, movep, moveq, muls, mulu,
    nbcd, neg, negx, nop, not,
    org, ori, orr,
    pea, 
    reg, reset, rol, ror, roxl, roxr, rte, rtr, rts, 
    sbcd, scc, set, stop, sub, suba, subi, subq, subx, swap,
    tas, trap, trapv, tst,
    unlk,
    // zig fmt: on

    pub fn mnemonics() []const std.builtin.Type.EnumField {
        return @typeInfo(@This()).@"enum".fields[@intFromEnum(@This().abcd)..];
    }

    pub fn mnemonicFromString(str: []const u8) ?Type {
        return mnemonics_map.get(str);
    }
};

const mnemonics_map = struct {
    const EncodedMnemonic = u56;
    const Entry = packed struct {
        type: Type,
        encoded_mnemonic: EncodedMnemonic,
    };

    const table = table: {
        for (1..36) |size_multiplier| {
            const possible_table = generateSizedTableWithSeed(Type.mnemonics().len * size_multiplier);
            if (possible_table) |tbl| break :table .{ .data = tbl[0], .seed = tbl[1] };
        }

        @compileError("mnemonics_map's size multiplier > 36");
    };

    fn generateSizedTableWithSeed(comptime size: usize) ?struct { [size]Entry, u32 } {
        const mnemonics = Type.mnemonics();

        for (15000..30000) |seed| {
            @setEvalBranchQuota(std.math.maxInt(u32));
            var data = [_]Entry{.{ .encoded_mnemonic = 0, .type = undefined }} ** size;

            for (mnemonics) |mnemonic| {
                const encoded_mnemonic = encode(mnemonic.name);
                const i = hash(encoded_mnemonic, seed, size);
                if (data[i].encoded_mnemonic != 0) break;
                data[i] = Entry{ .encoded_mnemonic = encoded_mnemonic, .type = @enumFromInt(mnemonic.value) };
            } else return .{ data, seed };
        }
        return null;
    }

    fn encode(str: []const u8) EncodedMnemonic {
        std.debug.assert(str.len > 1 and str.len < 8);

        const is_odd = str.len % 2 == 1;
        var value: EncodedMnemonic = if (is_odd) @intCast(str[0] | 0x20) else 0;
        var i: usize = @intFromBool(is_odd);

        //TODO: use a @ptrCast to []const u16 when the language will supports size changing casting.
        while (i != str.len) : (i += 2) {
            const wchar = @as(u16, str[i]) << 8 | str[i + 1];
            value = (value << 16) | (wchar | 0x2020);
        }

        return value;
    }

    inline fn hash(input: EncodedMnemonic, comptime seed: u32, comptime len: usize) usize {
        return std.hash.Murmur2_64.hashUint64WithSeed(@intCast(input), @intCast(seed)) % len;
    }

    pub fn get(str: []const u8) ?Type {
        if (str.len < 2 or str.len > 7) return null;

        const encoded_mnemonic = encode(str);
        const token = table.data[hash(encoded_mnemonic, table.seed, table.data.len)];

        return if (token.encoded_mnemonic == encoded_mnemonic) token.type else null;
    }

    test "mnemonic_map's entry size" {
        try std.testing.expectEqual(@bitSizeOf(Entry), 64);
    }
};

pub const Info = packed struct {
    type: Type,
    data: Data,
    relative_string: StringView,

    test "Token.Info's size" {
        try std.testing.expectEqual(@bitSizeOf(@This()), 64);
    }
};
