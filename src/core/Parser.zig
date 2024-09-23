const std = @import("std");
const Lexer = @import("Lexer");
const token = @import("token");

const This = @This();

const Handler = enum {
    label,
    mnemonic,
    size,
    firstOperand,
    comma,
    secondOperand,
    newLine,
};

const HandlerFn = *const fn (*This, token.Info) void;

const ValidAddressingModes = struct {
    const Data = std.bit_set.StaticBitSet(Mode.count() * 2);
    pub const Mode = enum {
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
            return @typeInfo(Mode).@"enum".fields[0..].len;
        }
    };

    pub const OperandPosition = enum {
        first,
        second,
    };

    data: Data,

    pub fn create(comptime first: anytype, comptime second: anytype) @This() {
        @setEvalBranchQuota(std.math.maxInt(u32));

        if (!isModeArray(first) or !isModeArray(second)) {
            @compileError("ValidaAddressingMode's first and second arguments must be Mode arrays.");
        }

        comptime var data: Data = Data.initEmpty();

        for (first) |mode| {
            data.set(getIndex(mode, .first));
        }

        for (second) |mode| {
            data.set(getIndex(mode, .second));
        }

        return @This(){ .data = data };
    }

    pub fn createSpecial() @This() {
        return .{ .data = Data.initFull() };
    }

    pub fn isModeValid(this: @This(), t: token.Type, comptime f_or_s: OperandPosition) bool {
        return this.data.isSet(getIndex(tokenTypeToMode(t), f_or_s));
    }

    pub fn isSpecial(this: @This()) bool {
        return this.data.isFull();
    }

    pub fn hasSecondOperand(this: @This()) bool {
        // TODO: consider making a pr to zig
        const Mask = @TypeOf(this.data.mask);
        const mask = ~@as(Mask, 0) >> (@bitSizeOf(Mask) - Mode.count());
        return (this.data.mask & mask) != 0;
    }

    fn tokenTypeToMode(t: token.Type) Mode {
        return switch (t) {
            .Dn => Mode.Dn,
            .An => Mode.An,
            .@"(An)" => Mode.@"(An)",
            .@"(An)+" => Mode.@"(An)+",
            .@"-(An)" => Mode.@"-(An)",
            .@"(d,An)" => Mode.@"(d,An)",
            .@"(d,An,Xi)" => Mode.@"(d,PC,Xn)",
            .absolute => Mode.ABS,
            .immediate, .immediate_label => Mode.imm,
            //TODO: PC
            else => @panic(""),
        };
    }

    fn getIndex(mode: Mode, f_or_s: OperandPosition) usize {
        const pos: usize = @intFromEnum(mode);
        const offset = Mode.count() * @intFromBool(f_or_s == .first);

        return pos + offset;
    }

    fn isModeArray(comptime arr: anytype) bool {
        const T = @TypeOf(arr);
        const type_info = @typeInfo(T);
        return switch (type_info) {
            .array => std.meta.Child(T) == Mode,
            else => false,
        };
    }
};

const mnemonics_to_addressing = struct {
    const first_mnemonic = @intFromEnum(token.Type.abcd);
    const last_mnemonic = first_mnemonic + token.Type.countMnemonics() - 1;
    const map = [token.Type.countMnemonics()]ValidAddressingModes{
        // ABCD
        ValidAddressingModes.createSpecial(),
        // ADD
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{ .Dn, .An, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
            [_]ValidAddressingModes.Mode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        ),
        // ADDA
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{ .Dn, .An, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
            [_]ValidAddressingModes.Mode{.An},
        ),
        // ADDI
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{.imm},
            [_]ValidAddressingModes.Mode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        ),
        // ADDQ
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{.imm},
            [_]ValidAddressingModes.Mode{ .Dn, .An, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        ),
        // ADDX
        ValidAddressingModes.createSpecial(),
        // AND
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
            [_]ValidAddressingModes.Mode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        ),
        // ANDI
        ValidAddressingModes.createSpecial(),
        // ASL
        ValidAddressingModes.createSpecial(),
        // ASR
        ValidAddressingModes.createSpecial(),
        // BCC todo handle all kinds
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{.ABS},
            [_]ValidAddressingModes.Mode{},
        ),
        // BCHG
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{ .Dn, .imm },
            [_]ValidAddressingModes.Mode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        ),
        // BCLR
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{ .Dn, .imm },
            [_]ValidAddressingModes.Mode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        ),
        // BRA
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{.ABS},
            [_]ValidAddressingModes.Mode{},
        ),
        // BSET
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{ .Dn, .imm },
            [_]ValidAddressingModes.Mode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        ),
        // BSR
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{.ABS},
            [_]ValidAddressingModes.Mode{},
        ),
        // BTST
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{ .Dn, .imm },
            [_]ValidAddressingModes.Mode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        ),
        // CHK
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
            [_]ValidAddressingModes.Mode{.Dn},
        ),
        // CLR
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
            [_]ValidAddressingModes.Mode{},
        ),
        // CMP
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{ .Dn, .An, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
            [_]ValidAddressingModes.Mode{.Dn},
        ),
        // CMPI
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{.imm},
            [_]ValidAddressingModes.Mode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)" },
        ),
        // CMPM
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{.@"(An)+"},
            [_]ValidAddressingModes.Mode{.@"(An)+"},
        ),
        // DBCC TODO: check better
        ValidAddressingModes.createSpecial(),
        // DC
        ValidAddressingModes.createSpecial(),
        // DCB
        ValidAddressingModes.createSpecial(),
        // DIVS
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
            [_]ValidAddressingModes.Mode{.Dn},
        ),
        // DIVU
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS, .@"(d,PC)", .@"(d,PC,Xn)", .imm },
            [_]ValidAddressingModes.Mode{.Dn},
        ),
        // DS
        ValidAddressingModes.createSpecial(),
        // END TODO: should not emit token
        ValidAddressingModes.createSpecial(),
        // EOR
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{.Dn},
            [_]ValidAddressingModes.Mode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        ),
        // EORI TODO: CCRS and SR
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{.imm},
            [_]ValidAddressingModes.Mode{ .Dn, .@"(An)", .@"(An)+", .@"-(An)", .@"(d,An)", .@"(d,An,Xi)", .ABS },
        ),
        // EQU
        ValidAddressingModes.createSpecial(),
        // EXG
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{ .Dn, .An },
            [_]ValidAddressingModes.Mode{ .Dn, .An },
        ),
        // EXT
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{.Dn},
            [_]ValidAddressingModes.Mode{},
        ),
        // ILLEGAL
        ValidAddressingModes.create(
            [_]ValidAddressingModes.Mode{},
            [_]ValidAddressingModes.Mode{},
        ),
        // TODO TODO TODO following mnemonics are just placeholder
        // JMP,
        ValidAddressingModes.createSpecial(),
        // JSR,
        ValidAddressingModes.createSpecial(),
        // LEA,
        ValidAddressingModes.createSpecial(),
        // LINK,
        ValidAddressingModes.createSpecial(),
        // LSL,
        ValidAddressingModes.createSpecial(),
        // LSR,
        ValidAddressingModes.createSpecial(),
        // MOVE,
        ValidAddressingModes.createSpecial(),
        // MOVEA,
        ValidAddressingModes.createSpecial(),
        // MOVEP,
        ValidAddressingModes.createSpecial(),
        // MOVEQ,
        ValidAddressingModes.createSpecial(),
        // MULS,
        ValidAddressingModes.createSpecial(),
        // MULU,
        ValidAddressingModes.createSpecial(),
        // NBCD,
        ValidAddressingModes.createSpecial(),
        // NEG,
        ValidAddressingModes.createSpecial(),
        // NEGX,
        ValidAddressingModes.createSpecial(),
        // NOP,
        ValidAddressingModes.createSpecial(),
        // NOT,
        ValidAddressingModes.createSpecial(),
        // ORG,
        ValidAddressingModes.createSpecial(),
        // ORI,
        ValidAddressingModes.createSpecial(),
        // ORR,
        ValidAddressingModes.createSpecial(),
        // PEA,
        ValidAddressingModes.createSpecial(),
        // REG,
        ValidAddressingModes.createSpecial(),
        // RESET,
        ValidAddressingModes.createSpecial(),
        // ROL,
        ValidAddressingModes.createSpecial(),
        // ROR,
        ValidAddressingModes.createSpecial(),
        // ROXL,
        ValidAddressingModes.createSpecial(),
        // ROXR,
        ValidAddressingModes.createSpecial(),
        // RTE,
        ValidAddressingModes.createSpecial(),
        // RTR,
        ValidAddressingModes.createSpecial(),
        // RTS,
        ValidAddressingModes.createSpecial(),
        // SBCD,
        ValidAddressingModes.createSpecial(),
        // SCC,
        ValidAddressingModes.createSpecial(),
        // SET,
        ValidAddressingModes.createSpecial(),
        // STOP,
        ValidAddressingModes.createSpecial(),
        // SUB,
        ValidAddressingModes.createSpecial(),
        // SUBA,
        ValidAddressingModes.createSpecial(),
        // SUBI,
        ValidAddressingModes.createSpecial(),
        // SUBQ,
        ValidAddressingModes.createSpecial(),
        // SUBX,
        ValidAddressingModes.createSpecial(),
        // SWAP,
        ValidAddressingModes.createSpecial(),
        // TAS,
        ValidAddressingModes.createSpecial(),
        // TRAP,
        ValidAddressingModes.createSpecial(),
        // TRAPV,
        ValidAddressingModes.createSpecial(),
        // TST,
        ValidAddressingModes.createSpecial(),
        // UNLK,
        ValidAddressingModes.createSpecial(),
    };

    pub fn get(t: token.Type) ?ValidAddressingModes {
        return if (isMnemonic(t)) map[hash(t)] else null;
    }

    fn hash(t: token.Type) usize {
        const token_val = @intFromEnum(t);
        std.debug.assert(token_val >= first_mnemonic and token_val <= last_mnemonic);

        return token_val - first_mnemonic;
    }

    fn isMnemonic(t: token.Type) bool {
        const token_val = @intFromEnum(t);

        return token_val >= first_mnemonic and token_val <= last_mnemonic;
    }
};

const handlers = [_]HandlerFn{
    label,
    mnemonic,
    size,
    firstOperand,
    comma,
    secondOperand,
    newLine,
};

lexer: *Lexer,
handler: Handler = .label,
valid_addressing: ValidAddressingModes = undefined,

pub fn init(lexer: *Lexer) This {
    return .{ .lexer = lexer };
}

pub fn deint(_: *This) void {}

pub fn parse(this: *This) void {
    while (this.lexer.tokens.consume()) |ti| {
        this.handle(ti);
    } else |_| {}
}

fn handle(this: *This, ti: token.Info) void {
    handlers[@intFromEnum(this.handler)](this, ti);
}

fn label(this: *This, ti: token.Info) void {
    this.handler = .mnemonic;

    if (ti.type != .label) {
        this.handle(ti);
    }

    // gestici lable
    //
    //
}

fn mnemonic(this: *This, ti: token.Info) void {
    this.handler = .size;
    this.valid_addressing = if (mnemonics_to_addressing.get(ti.type)) |addressing| addressing else @panic(@tagName(ti.type));
}

fn size(this: *This, ti: token.Info) void {
    this.handler = .firstOperand;
    if (ti.type != .B and ti.type != .W and ti.type != .L) {
        // Setta size alla dafult
        this.handle(ti);
    }
    // Set size al ti
}

fn firstOperand(this: *This, ti: token.Info) void {
    this.handler = .comma;
    if (!this.valid_addressing.isModeValid(ti.type, .first)) {
        @panic("");
    }
}

fn comma(this: *This, ti: token.Info) void {
    this.handler = .secondOperand;
    if (ti.type != .comma) {
        @panic("not comma");
    }
}

fn secondOperand(this: *This, ti: token.Info) void {
    this.handler = .newLine;
    if (!this.valid_addressing.isModeValid(ti.type, .second)) {
        @panic("");
    }
}
fn newLine(this: *This, ti: token.Info) void {
    _ = ti; // autofix
    this.handler = .label;
    // if(!newLine){
    // error
    // }
    //
    // aggiorna poszione relativa
}
