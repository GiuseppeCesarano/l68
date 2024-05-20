const std = @import("std");

pub const NumberBase = enum(u8) {
    const This = @This();

    binary = 2,
    octal = 8,
    decimal = 10,
    hexdecimal = 16,

    pub fn fromChar(char: u8) !This {
        return switch (char) {
            '%' => .binary,
            '@' => .octal,
            ' ' => .decimal,
            '$' => .hexdecimal,
            else => error.InvalidCharacter,
        };
    }

    pub fn toChar(base: This) u8 {
        return switch (base) {
            .binary => '%',
            .octal => '@',
            .decimal => ' ',
            .hexdecimal => '$',
        };
    }
};

pub const Token = union(enum(u8)) {
    const This = @This();

    // Literals
    label: []const u8,
    immediate: struct { value: i64, base: NumberBase },
    absolute: struct { location: u32, base: NumberBase },
    char: u8,
    string: []const u8,
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

    pub fn Types() type {
        return @typeInfo(@This()).Union.tag_type.?;
    }

    pub fn mnemonics() []const std.builtin.Type.EnumField {
        const first = @intFromEnum(Types().abcd);
        const last = @intFromEnum(Types().unlk);

        return @typeInfo(Types()).Enum.fields[first..last];
    }
};
