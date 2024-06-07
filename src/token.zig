const std = @import("std");

pub const Type = union(enum(u8)) {
    const This = @This();

    // Literals
    label: []const u8,
    immediate: i64,
    immediate_label: []const u8,
    absolute: u32,
    char: u8,
    string: []const u8,

    // Single charchater tokens
    comma,
    left_parentheses,
    right_parentheses,
    plus,
    minus,
    multiply,
    divide,

    // Dual charchater tokens
    byte_size,
    word_size,
    long_size,
    data_register: u8,
    address_register: u8,

    // mnemonics (must be ketp sequential)
    abcd,
    add,
    adda,
    addi,
    addq,
    andd,
    andi,
    asl,
    asr,
    bcc,
    bchg,
    bclr,
    bra,
    bset,
    bsr,
    btst,
    chk,
    clr,
    cmp,
    cmpa,
    cmpi,
    cmpm,
    dbcc,
    dc,
    dcb,
    divs,
    ds,
    end,
    eor,
    eori,
    equ,
    exg,
    ext,
    illegal,
    jmp,
    jsr,
    lea,
    link,
    lsl,
    lsr,
    move,
    movea,
    movep,
    moveq,
    muls,
    mulu,
    nbcd,
    neg,
    negx,
    nop,
    not,
    org,
    ori,
    orr,
    pea,
    reg,
    reset,
    rol,
    ror,
    roxl,
    roxr,
    rte,
    rtr,
    rts,
    sbcd,
    scc,
    set,
    stop,
    sub,
    suba,
    subi,
    subq,
    subx,
    swap,
    tas,
    trap,
    trapv,
    tst,
    unlk,

    pub fn TagType() type {
        return @typeInfo(@This()).Union.tag_type.?;
    }

    pub fn mnemonics() []const std.builtin.Type.EnumField {
        return @typeInfo(TagType()).Enum.fields[@intFromEnum(TagType().abcd)..];
    }
};

pub const mnemonics_map = struct {
    const table_info = table: {
        var size_multiplier: u32 = 1;
        while (size_multiplier <= 35) : (size_multiplier += 1) {
            const t = generateSizedTableWithSeed(Type.mnemonics().len * size_multiplier);
            if (t[2]) break :table .{ .data = t[0], .seed = t[1] };
        }
        @compileError("mnemonics_map's size multiplier > 35");
    };

    fn generateSizedTableWithSeed(comptime size: usize) struct { [size]struct { u64, Type }, u32, bool } {
        const mnemonics = Type.mnemonics();
        var data = [_]struct { u64, Type }{.{ 0, .comma }} ** size;
        var fill: usize = 0;
        var seed: u32 = 0;
        while (fill != Type.mnemonics().len and seed < 15000) : (seed += 1) {
            fill = 0;
            @setEvalBranchQuota(std.math.maxInt(u32));
            for (mnemonics) |mnemonic| {
                const full, const half = encodeFullAndHalf(mnemonic.name);
                const i = hash(half, seed, size);
                if (data[i][0] == 0) {
                    data[i] = .{ full, @unionInit(Type, mnemonic.name, {}) };
                    fill += 1;
                } else break;
            }
        }
        return .{ data, seed - 1, fill == Type.mnemonics().len };
    }

    fn encodeFullAndHalf(str: []const u8) struct { u64, u32 } {
        var full: u64 = 0;
        for (str) |c| {
            full = (full << 8) | (c | 0b00100000);
        }
        const half: u32 = @intCast(((full >> @intCast(8 * (str.len - 2))) << 16) | (full & 0xFFFF));
        return .{ full, half };
    }

    fn hash(input: u32, seed: u32, len: usize) usize {
        return std.hash.Murmur2_32.hashUint32WithSeed(input, seed) % len;
    }

    pub fn get(str: []const u8) ?Type {
        if (str.len < 2 or str.len > 8) return null;
        const full, const half = encodeFullAndHalf(str);
        const token = table_info.data[hash(half, table_info.seed, table_info.data.len)];
        return if (token[0] == full) token[1] else null;
    }
};
