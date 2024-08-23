const std = @import("std");
const Lexer = @import("Lexer");
const token = @import("token");

const This = @This();

lexer: *Lexer,

pub fn init(lexer: *Lexer) This {
    return .{ .lexer = lexer };
}

pub fn deint(_: *This) void {}

pub fn parse(this: *This) void {
    while (this.lexer.tokens.consume()) |_| {} else |_| {}
}
