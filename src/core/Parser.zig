const std = @import("std");
const Lexer = @import("Lexer");
const asmd = @import("asm");

const This = @This();

const Handler = enum {
    label,
    mnemonic,
    size,
    first_operand,
    comma,
    second_operand,
    new_line,
    skip,
};

const HandlerFn = *const fn (*This, asmd.Token) void;

const handlers = [_]HandlerFn{
    label,
    mnemonic,
    size,
    firstOperand,
    comma,
    secondOperand,
    newLine,
    skip,
};

lexer: *Lexer,
handler: Handler = .label,
mnemn: *const asmd.Mnemonic = undefined,
line_start: u32 = 0,
line_number: u32 = 0,

pub fn init(lexer: *Lexer) This {
    return .{ .lexer = lexer };
}

pub fn deint(_: *This) void {}

pub fn parse(this: *This) void {
    while (this.lexer.tokens.consume()) |t| {
        this.handle(t);
    } else |_| {}
}

inline fn handle(this: *This, t: asmd.Token) void {
    handlers[@intFromEnum(this.handler)](this, t);
}

fn label(this: *This, t: asmd.Token) void {
    this.handler = if (t.id != .new_line) .mnemonic else .new_line;
    if (t.id != .label) {
        this.handle(t);
    }
}

fn mnemonic(this: *This, t: asmd.Token) void {
    this.handler = if (t.id != .dc and t.id != .equ) .size else .skip; // TODO: Remove the skip fn and handle dc and equ
    this.mnemn = t.toMnemonicInstance() catch @panic(@tagName(t.id));
}

fn size(this: *This, t: asmd.Token) void {
    this.handler = if (this.mnemn.hasOperand(.first)) .first_operand else .new_line;
    if (t.toSize()) |s| {
        if (!(this.mnemn.isSizeValid(s))) {
            std.debug.print("line: {}, size invalid.\n{s}\n", .{ this.line_number, t.relative_string.toSliceWithOffset(this.lexer.text, this.line_start) });
        }
    } else |_| {
        // TODO: Set size to default size;
        this.handle(t);
    }
}

fn firstOperand(this: *This, t: asmd.Token) void {
    this.handler = if (this.mnemn.hasOperand(.second)) .comma else .new_line;

    if (t.id == .label) return; // TODO: CHANGE
    const addressing_mode = t.toAddressingMode() catch @panic("exected addressing mode");

    if (!this.mnemn.isAddressingModeValid(addressing_mode, .first)) {
        std.debug.print("line: {}, addressing mode invalid.\n{s}\n", .{ this.line_number, t.relative_string.toSliceWithOffset(this.lexer.text, this.line_start) });
    }
}

fn comma(this: *This, t: asmd.Token) void {
    this.handler = .second_operand;
    if (t.id != .comma) {
        std.debug.print("line: {} not comma", .{this.line_number});
    }
}

fn secondOperand(this: *This, t: asmd.Token) void {
    this.handler = .new_line;

    if (t.id == .label) return; // TODO: CHANGE
    const addressing_mode = t.toAddressingMode() catch @panic("exected addressing mode");

    if (!this.mnemn.isAddressingModeValid(addressing_mode, .second)) {
        std.debug.print("line: {}, addressing mode invalid.\n{s}\n", .{ this.line_number, t.relative_string.toSliceWithOffset(this.lexer.text, this.line_start) });
    }
}

fn newLine(this: *This, t: asmd.Token) void {
    this.line_start = t.data.Number;
    this.handler = .label;
    this.line_number += 1;
    // TODO: better check
}

fn skip(this: *This, t: asmd.Token) void {
    if (t.id == .new_line) {
        this.handler = .label;
    }
}
