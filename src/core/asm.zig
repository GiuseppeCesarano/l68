const std = @import("std");

const Size = enum {
    B,
    W,
    L,

    pub fn count() usize {
        return @typeInfo(@This()).@"enum".fields[0..].len;
    }
};

pub const AddressingMode = enum {
    Dn,
    An,
    @"(An)",
    @"(An)+",
    @"-(An)",
    @"(d,An)",
    @"(d,An,Xi)",
    ABS,
    @"(d,PC)",
    @"(d,PC,Xn)",
    imm,

    pub fn count() usize {
        return @typeInfo(@This()).@"enum".fields[0..].len;
    }
};

pub const Literal = enum {
    label,
    string,
    comma,
    new_line,

    pub fn count() usize {
        return @typeInfo(@This()).@"enum".fields[0..].len;
    }
};

pub const OperandPosition = enum {
    first,
    second,
};

pub const Mnemonic = struct {
    const This = @This();
    pub const ValidSizes = std.bit_set.IntegerBitSet(3);
    pub const ValidAddressingModes = std.bit_set.IntegerBitSet(AddressingMode.count());
    pub const StrRepresentation = [7:0]u8;

    str: StrRepresentation = [_:0]u8{0} ** 7,
    valid_sizes: ValidSizes = ValidSizes.initEmpty(),
    valid_addressing_modes: [2]ValidAddressingModes = .{ ValidAddressingModes.initEmpty(), ValidAddressingModes.initEmpty() },

    pub fn create(comptime str: [:0]const u8, comptime sizes: anytype, comptime first_operand_modes: anytype, comptime second_operand_modes: anytype) This {
        if (str.len > 7) @compileError("mnemonic string rappresentation has more than 7 chars");
        if (!isTypeArray(Size, sizes)) @compileError("sizes must be an array of Size");
        if (!isTypeArray(AddressingMode, first_operand_modes)) @compileError("first_operand_modes must be an array of Mode");
        if (!isTypeArray(AddressingMode, second_operand_modes)) @compileError("second_operand_modes must be an array of Mode");

        var ret: This = .{};
        std.mem.copyForwards(u8, &ret.str, str);

        for (sizes) |size| {
            ret.valid_sizes.set(getSizeIndex(size));
        }

        for (first_operand_modes) |mode| {
            @setEvalBranchQuota(std.math.maxInt(u32));
            ret.valid_addressing_modes[0].set(getModeIndex(mode));
        }

        for (second_operand_modes) |mode| {
            ret.valid_addressing_modes[1].set(getModeIndex(mode));
        }

        return ret;
    }

    pub fn isSizeValid(this: This, size: Size) bool {
        const index = getSizeIndex(size);
        return this.valid_sizes.isSet(index);
    }

    pub fn getDefaultSize(this: This) ?Size {
        return if (this.valid_sizes.findFirstSet()) |size| @enumFromInt(size) else null;
    }

    pub fn isAddressingModeValid(this: This, mode: anytype, comptime f_or_s: OperandPosition) bool {
        const index = getModeIndex(mode);
        return this.valid_addressing_modes[@intFromEnum(f_or_s)].isSet(index);
    }

    pub fn isSpecial(this: This) bool {
        const mask = ~@as(ValidAddressingModes.MaskInt, 0);
        return (this.valid_addressing_modes[0].mask & this.valid_addressing_modes[1].mask) == mask;
    }

    pub fn hasOperand(this: This, comptime f_or_s: OperandPosition) bool {
        return this.valid_addressing_modes[@intFromEnum(f_or_s)].mask != 0;
    }

    fn isTypeArray(Type: type, comptime arr: anytype) bool {
        const T = @TypeOf(arr);
        const type_info = @typeInfo(T);
        return switch (type_info) {
            .array => std.meta.Child(T) == Type,
            else => false,
        };
    }

    inline fn getSizeIndex(size: Size) usize {
        return @intFromEnum(size);
    }

    inline fn getModeIndex(mode: anytype) usize {
        return @intFromEnum(mode);
    }
};

// zig fmt: off
pub const mnemonics = [_]Mnemonic{
    Mnemonic.create("abcd", // TODO: only Dn, Dn or -(An),-(An)
        [_]Size{ .B }, 
        [_]AddressingMode{ .Dn, .@"-(An)" }, 
        [_]AddressingMode{ .Dn, .@"-(An)" }),
    Mnemonic.create("add", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .An, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }),
    Mnemonic.create("adda", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .An, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
        [_]AddressingMode{ .An }),
    Mnemonic.create("addi", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }),
    Mnemonic.create("addq", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .imm },
        [_]AddressingMode{ .Dn, .An, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }),
    Mnemonic.create("addx", // TODO: only Dn, Dn or -(An),-(An)
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .@"-(An)" }, 
        [_]AddressingMode{ .Dn, .@"-(An)" }),
    Mnemonic.create("and", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }),
    Mnemonic.create("andi", // TODO: SR e CCR
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }),
    Mnemonic.create("asl", // TODO: second argument is optional
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }),
    Mnemonic.create("asr", // TODO: second argument is optional
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }),
    Mnemonic.create("bcc", // TODO: takes a label and offset
        [_]Size{}, 
        [_]AddressingMode{ .ABS }, 
        [_]AddressingMode{}),
    Mnemonic.create("bcs", // TODO: takes a label and offset
        [_]Size{}, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("beq", // TODO: takes a label and offset
        [_]Size{}, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("bge", // TODO: takes a label and offset
        [_]Size{}, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("bgt", // TODO: takes a label and offset
        [_]Size{}, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("bhi", // TODO: takes a label and offset
        [_]Size{}, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("bhs", // TODO: takes a label and offset
        [_]Size{}, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("ble", // TODO: takes a label and offset
        [_]Size{}, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("blo", // TODO: takes a label and offset
        [_]Size{}, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("bls", // TODO: takes a label and offset
        [_]Size{}, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("blt", // TODO: takes a label and offset
        [_]Size{}, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("bmi", // TODO: takes a label and offset
        [_]Size{}, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("bne", // TODO: takes a label and offset
        [_]Size{}, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("bpl", // TODO: takes a label and offset
        [_]Size{}, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("bvc", // TODO: takes a label and offset
        [_]Size{}, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("bvs", // TODO: takes a label and offset
        [_]Size{}, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("bchg", 
        [_]Size{ .B, .L }, 
        [_]AddressingMode{ .Dn, .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }),
    Mnemonic.create("bclr", 
        [_]Size{ .B, .L }, 
        [_]AddressingMode{ .Dn, .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }),
    Mnemonic.create("bra", 
        [_]Size{ .B, .W }, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("bset", 
        [_]Size{ .B, .L }, 
        [_]AddressingMode{ .Dn, .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }),
    Mnemonic.create("bsr", 
        [_]Size{ .B, .W }, 
        [_]AddressingMode{ .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("btst", 
        [_]Size{ .B, .L }, 
        [_]AddressingMode{ .Dn, .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)" }),
    Mnemonic.create("chk", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, },
        [_]AddressingMode{ .Dn, }),
    Mnemonic.create("clr", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, },
        [_]AddressingMode{}),
    Mnemonic.create("cmp", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .An, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
        [_]AddressingMode{ .Dn }),
    Mnemonic.create("cmpa", 
        [_]Size{ .W, .L }, 
        [_]AddressingMode{ .Dn, .An, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
        [_]AddressingMode{ .An }),
    Mnemonic.create("cmpi", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)" }),
    Mnemonic.create("cmpm", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .@"(An)+" },
        [_]AddressingMode{ .@"(An)+" }),
    Mnemonic.create("dbcc", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("dbcs", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("dbeq", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("dbge", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("dbgt", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("dbhi", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("dbhs", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("dble", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("dblo", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("dbls", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("dblt", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("dbmi", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("dbne", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("dbpl", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("dbvc", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("dbvs", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("dc", //TODO: check asim manual 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .ABS }),
    Mnemonic.create("divs", //TODO: explore whath longword/word means in the manual
        [_]Size{ .W, .L }, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS,.@"(d,PC)", .@"(d,PC,Xn)", .imm},
        [_]AddressingMode{ .Dn }),
    Mnemonic.create("divu", //TODO: explore whath longword/word means in the manual
        [_]Size{ .W, .L }, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS,.@"(d,PC)", .@"(d,PC,Xn)", .imm},
        [_]AddressingMode{ .Dn }),
    Mnemonic.create("ds", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .ABS, },
        [_]AddressingMode{}),
    Mnemonic.create("end", 
        [_]Size{}, 
        [_]AddressingMode{},
        [_]AddressingMode{}),
    Mnemonic.create("eor", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)",.@"(d,An)", .@"(d,An,Xi)", .ABS, }),
    Mnemonic.create("eori", //TODO: CC and SR 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)",.@"(d,An)", .@"(d,An,Xi)", .ABS, }),
    Mnemonic.create("equ", //TODO: check asim manual
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .imm, .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("exg", // TODO: if first op is Dn second op should be Dn, same for An
        [_]Size{ .L }, 
        [_]AddressingMode{ .Dn, .An }, 
        [_]AddressingMode{ .Dn, .An }),
    Mnemonic.create("ext", 
        [_]Size{ .W, .L }, 
        [_]AddressingMode{ .Dn }, 
        [_]AddressingMode{}),
    Mnemonic.create("illegal", 
        [_]Size{}, 
        [_]AddressingMode{}, 
        [_]AddressingMode{}),
    Mnemonic.create("jmp", 
        [_]Size{}, 
        [_]AddressingMode{ .@"(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)" }, 
        [_]AddressingMode{}),
    Mnemonic.create("jsr", 
        [_]Size{}, 
        [_]AddressingMode{ .@"(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)" }, 
        [_]AddressingMode{}),
    Mnemonic.create("lea", 
        [_]Size{ .L }, 
        [_]AddressingMode{ .@"(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)"}, 
        [_]AddressingMode{ .An }),
    Mnemonic.create("link", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .An }, 
        [_]AddressingMode{ .imm }),
    Mnemonic.create("lsl", // TODO: second argument is optional
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }),
    Mnemonic.create("lsr", // TODO: second argument is optional
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }),
    Mnemonic.create("move", // TODO: ccr sr ups
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .An, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, }),
    Mnemonic.create("movea", // TODO: second argument is optional
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .An, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
        [_]AddressingMode{ .An }),
    Mnemonic.create("movem", // TODO: needs token support
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{},
        [_]AddressingMode{}),
    Mnemonic.create("movep", // TODO: if first op dn second must be (d,an) and vice versa
        [_]Size{ .W, .L }, 
        [_]AddressingMode{ .Dn, .@"(d,An)" },
        [_]AddressingMode{ .Dn, .@"(d,An)" }),
    Mnemonic.create("moveq", // TODO: if first op dn second must be (d,an) and vice versa
        [_]Size{ .L }, 
        [_]AddressingMode{ .imm },
        [_]AddressingMode{ .Dn, .@"(d,An)" }),
    Mnemonic.create("muls", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
        [_]AddressingMode{ .Dn, }),
    Mnemonic.create("mulu", 
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
        [_]AddressingMode{ .Dn, }),
    Mnemonic.create("nbcd", 
        [_]Size{ .B }, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, },
        [_]AddressingMode{}),
    Mnemonic.create("neg", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, },
        [_]AddressingMode{}),
    Mnemonic.create("negx", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, },
        [_]AddressingMode{}),
    Mnemonic.create("nop", 
        [_]Size{}, 
        [_]AddressingMode{},
        [_]AddressingMode{}),
    Mnemonic.create("not", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, },
        [_]AddressingMode{}),
    Mnemonic.create("or", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, }),
    Mnemonic.create("org", 
        [_]Size{}, 
        [_]AddressingMode{ .ABS, },
        [_]AddressingMode{}),
    Mnemonic.create("ori", //TODO: ccr sr
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, }),
    Mnemonic.create("pea", //TODO: ccr sr
        [_]Size{ .L }, 
        [_]AddressingMode{ .@"(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)" },
        [_]AddressingMode{}),
    Mnemonic.create("reset",
        [_]Size{}, 
        [_]AddressingMode{},
        [_]AddressingMode{}),
    Mnemonic.create("rol", // TODO: second argument is optional
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }),
    Mnemonic.create("ror", // TODO: second argument is optional
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }),
    Mnemonic.create("roxl", // TODO: second argument is optional
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }),
    Mnemonic.create("roxr", // TODO: second argument is optional
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }),
    Mnemonic.create("rte",
        [_]Size{}, 
        [_]AddressingMode{},
        [_]AddressingMode{}),
    Mnemonic.create("rtr",
        [_]Size{}, 
        [_]AddressingMode{},
        [_]AddressingMode{}),
    Mnemonic.create("rts",
        [_]Size{}, 
        [_]AddressingMode{},
        [_]AddressingMode{}),
    Mnemonic.create("sbcd", // TODO: only Dn, Dn or -(An),-(An)
        [_]Size{ .B }, 
        [_]AddressingMode{ .Dn, .@"-(An)" }, 
        [_]AddressingMode{ .Dn, .@"-(An)" }),
    Mnemonic.create("scc", 
        [_]Size{}, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS }, 
        [_]AddressingMode{}),
    Mnemonic.create("scs", 
        [_]Size{}, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("seq", 
        [_]Size{}, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("sge", 
        [_]Size{}, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("sgt", 
        [_]Size{}, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("shi", 
        [_]Size{}, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("shs", 
        [_]Size{}, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("sle", 
        [_]Size{}, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("slo", 
        [_]Size{}, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("sls", 
        [_]Size{}, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("slt", 
        [_]Size{}, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("smi", 
        [_]Size{}, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("sne", 
        [_]Size{}, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("spl", 
        [_]Size{}, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("svc", 
        [_]Size{}, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("svs", 
        [_]Size{}, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        [_]AddressingMode{}),
    Mnemonic.create("stop", 
        [_]Size{}, 
        [_]AddressingMode{ .imm },
        [_]AddressingMode{}),
    Mnemonic.create("sub", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .An, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, }),
    Mnemonic.create("suba", 
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .An, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
        [_]AddressingMode{ .An }),
    Mnemonic.create("subi",
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .imm },
        [_]AddressingMode{ .An }),
    Mnemonic.create("subq",
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .imm },
        [_]AddressingMode{ .Dn, .An, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, }),
    Mnemonic.create("subx", // TODO: only Dn, Dn or -(An),-(An)
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .@"-(An)" }, 
        [_]AddressingMode{ .Dn, .@"-(An)" }),
    Mnemonic.create("swap",
        [_]Size{ .W }, 
        [_]AddressingMode{ .Dn }, 
        [_]AddressingMode{}),
    Mnemonic.create("tas",
        [_]Size{ .B }, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, },
        [_]AddressingMode{}),
    Mnemonic.create("trap",
        [_]Size{}, 
        [_]AddressingMode{ .imm },
        [_]AddressingMode{}),
    Mnemonic.create("trapv",
        [_]Size{}, 
        [_]AddressingMode{},
        [_]AddressingMode{}),
    Mnemonic.create("tst",
        [_]Size{ .B, .W, .L }, 
        [_]AddressingMode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
        [_]AddressingMode{}),
    Mnemonic.create("unlk",
        [_]Size{}, 
        [_]AddressingMode{ .An },
        [_]AddressingMode{}),
};
// zig fmt: on

pub const Token = packed struct {
    pub const Id = Id: {
        const EnumField = std.builtin.Type.EnumField;
        var fields: [mnemonics.len + Size.count() + Literal.count() + AddressingMode.count()]EnumField = undefined;
        var index = 0;

        var len = mnemonics.len;
        while (index < len) : (index += 1) {
            const end = std.mem.indexOfScalar(u8, &mnemonics[index].str, 0) orelse 7;
            fields[index] = EnumField{ .name = @ptrCast(mnemonics[index].str[0 .. end + 1]), .value = index };
        }

        for ([_]type{ Size, AddressingMode, Literal }) |Current| {
            const current_fields = @typeInfo(Current).@"enum".fields;
            const offset = len;
            len += current_fields.len;
            while (index < len) : (index += 1) {
                fields[index] = EnumField{ .name = current_fields[index - offset].name, .value = index };
            }
        }

        const BaseId = enum(u8) {};
        var base_info = @typeInfo(BaseId).@"enum";
        base_info.fields = &fields;

        break :Id @Type(.{ .@"enum" = base_info });
    };

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

    pub const ConversionError = error{
        NotMnemonic,
        NotSize,
        NotAddressingMode,
    };

    id: Id,
    data: Data,
    relative_string: @import("compact").StringView,

    pub fn toMnemonicInstance(this: @This()) ConversionError!*const Mnemonic {
        const index = @intFromEnum(this.id);
        return if (index < mnemonics.len) &mnemonics[index] else ConversionError.NotMnemonic;
    }

    pub fn toSize(this: @This()) ConversionError!Size {
        const index = @intFromEnum(this.id);
        const lower_bound = mnemonics.len;
        const upper_bound = lower_bound + Size.count();
        return if (index >= lower_bound and index < upper_bound) @enumFromInt(@intFromEnum(this.id) - lower_bound) else ConversionError.NotSize;
    }

    pub fn toAddressingMode(this: @This()) ConversionError!AddressingMode {
        const index = @intFromEnum(this.id);
        const lower_bound = mnemonics.len + Size.count();
        const upper_bound = lower_bound + AddressingMode.count();
        return if (index >= lower_bound and index < upper_bound) @enumFromInt(@intFromEnum(this.id) - lower_bound) else ConversionError.NotAddressingMode;
    }

    test "Token.Info's size" {
        try std.testing.expectEqual(@bitSizeOf(@This()), 64);
    }
};

pub const Statement = struct {
    label: ?[]const u8,
    mnemonic: *const Mnemonic,
    size: ?Size,
    operand: [2]?AddressingMode,
};
