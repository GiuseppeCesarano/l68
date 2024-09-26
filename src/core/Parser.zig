const std = @import("std");
const Lexer = @import("Lexer");
const Token = @import("asm").Token;
const AddressingMode = @import("asm").AddressingMode;

const This = @This();

const Handler = enum {
    label,
    mnemonic,
    size,
    first_operand,
    comma,
    second_operand,
    new_line,
};

const HandlerFn = *const fn (*This, Token) void;

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
// valid_addressing: AddressingMode = undefined,

pub fn init(lexer: *Lexer) This {
    return .{ .lexer = lexer };
}

pub fn deint(_: *This) void {}

pub fn parse(this: *This) void {
    while (this.lexer.tokens.consume()) |t| {
        this.handle(t);
    } else |_| {}
}

inline fn handle(this: *This, t: Token) void {
    handlers[@intFromEnum(this.handler)](this, t);
}

fn label(this: *This, t: Token) void {
    this.handler = .mnemonic;
    switch (t.id) {
        .label => {
            // TODO: act on the label
        },
        .new_line => {
            this.handler = .label;
        },
        else => {
            this.handle(t);
        },
    }
}

fn mnemonic(this: *This, _: Token) void {
    this.handler = .size;
}

fn size(this: *This, t: Token) void {
    this.handler = .first_operand;
    if (t.id != .B and t.id != .W and t.id != .L) {
        // Setta size alla dafult
        this.handle(t);
    }
    // Set size al t
}

fn firstOperand(this: *This, _: Token) void {
    this.handler = if (true) .comma else .new_line;
    if (false) {
        @panic("First operand not valid");
    }
}

fn comma(this: *This, t: Token) void {
    this.handler = .second_operand;
    if (t.id != .comma) {
        @panic("not comma");
    }
}

fn secondOperand(this: *This, _: Token) void {
    this.handler = .new_line;
    if (false) {
        @panic("Second operand not valid");
    }
}
fn newLine(this: *This, t: Token) void {
    _ = t; // autofix
    this.handler = .label;
    // if(!newLine){
    // error
    // }
    //
    // aggiorna poszione relatva
}
