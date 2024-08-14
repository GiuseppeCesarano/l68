const std = @import("std");
const CompactStringView = @import("CompactStringView");

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
        return @typeInfo(@This()).Enum.fields[@intFromEnum(@This().abcd)..];
    }
};

const mnemonics_map = struct {
    const Whole = u56;
    const Part = u32;
    const Entry = packed struct {
        whole: Whole,
        type: Type,
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
            var data = [_]Entry{.{ .whole = 0, .type = undefined }} ** size;

            for (mnemonics) |mnemonic| {
                const whole, const part = encodeWholeAndPart(mnemonic.name);
                const i = hash(part, seed, size);
                if (data[i].whole != 0) break;
                data[i] = Entry{ .whole = whole, .type = @enumFromInt(mnemonic.value) };
            } else return .{ data, seed };
        }
        return null;
    }

    fn encodeWholeAndPart(str: []const u8) struct { Whole, Part } {
        std.debug.assert(str.len > 1 and str.len < 8);

        const is_odd = str.len % 2 == 1;
        var whole: Whole = if (is_odd) @intCast(str[0] | 0x20) else 0;
        var i: usize = @as(usize, @intCast(@intFromBool(is_odd)));

        //TODO: use a []const u16 when the language will supports casting from []const u8 to []const u16
        while (i != str.len) : (i += 2) {
            const wchar = @as(u16, str[i]) << 8 | str[i + 1];
            whole = (whole << 16) | (wchar | 0x2020);
        }

        const part: Part = @intCast(((whole >> @intCast(8 * (str.len - 2))) << 16) | (whole & 0xFFFF));

        return .{ whole, part };
    }

    fn hash(input: Part, seed: u32, comptime len: usize) usize {
        const fp = input ^ seed;
        return (fp ^ (fp << 1)) % len;
    }

    pub inline fn get(str: []const u8) ?Type {
        if (str.len < 2 or str.len > 7) return null;

        const whole, const part = encodeWholeAndPart(str);
        const token = table.data[hash(part, table.seed, table.data.len)];

        return if (token.whole == whole) token.type else null;
    }
};

type: Type,
data: Data,
relative_string: CompactStringView,

pub fn mnemonicStrToType(str: []const u8) ?Type {
    return mnemonics_map.get(str);
}
