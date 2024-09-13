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

    fn countMnemonics() usize {
        return @typeInfo(@This()).@"enum".fields[@intFromEnum(@This().abcd)..].len;
    }

    pub fn mnemonicsAsKeyValues() [countMnemonics()]struct { [7]u8, Type } {
        const Kv = struct { [7]u8, Type };
        var kvs = [_]Kv{.{ [7]u8{ 0, 0, 0, 0, 0, 0, 0 }, undefined }} ** countMnemonics();
        const base = @intFromEnum(@This().abcd);

        for (&kvs, 0..) |*kv, i| {
            kv[1] = @enumFromInt(base + i);

            const name = @tagName(kv[1]);
            std.debug.assert(name.len < 8);

            std.mem.copyForwards(u8, &kv[0], name);
        }

        return kvs;
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
