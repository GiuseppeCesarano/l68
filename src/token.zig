const std = @import("std");

pub const Token = union(enum(u8)) {
    const This = @This();

    // Literals
    label: []const u8,
    number: struct { value: i64, is_hex: bool },
    ram: struct { location: u32, is_hex: bool },
    char: u8,
    string: []const u8,
    err_line: []const u8,
    comment: []const u8,

    // Single charchater tokens
    comma,

    // Single or dual charchater tokens
    left_parentheses,
    right_parentheses,
    minus_left_parentheses,
    right_parentheses_plus,
    new_line,

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
    divs,
    end,
    eor,
    eori,
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
    orr,
    ori,
    pea,
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

    pub fn Types() type {
        return @typeInfo(@This()).Union.tag_type.?;
    }

    pub fn mnemonics() []const std.builtin.Type.EnumField {
        const first = @intFromEnum(Types().abcd);
        const last = @intFromEnum(Types().unlk);

        return @typeInfo(Types()).Enum.fields[first..last];
    }
};
