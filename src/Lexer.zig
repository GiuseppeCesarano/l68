const std = @import("std");
const Token = @import("Token");
const fmt = @import("helpers").fmt;

const This = @This();

text: []const u8,
tokens: std.ArrayList(Token),
token_start: u32 = 0,
line_number: u32 = 0,
line_start: u32 = 0,
position: u32 = 0,

const not_delimiter_map = set: {
    const len = std.math.maxInt(u8) + 1;
    var bitset = std.bit_set.StaticBitSet(len).initEmpty();

    for (0..len) |index| {
        @setEvalBranchQuota(5000);
        bitset.setValue(index, switch (index) {
            'a'...'z', 'A'...'Z', '0'...'9', '_' => true,
            else => false,
        });
    }
    break :set bitset;
};

const scan_map = map: {
    var kvs: [std.math.maxInt(u8) + 1]?*const fn (*This) void = undefined;
    for (&kvs, 0..) |*value, key| {
        value.* = switch (key) {
            ',' => comma,
            '(' => leftParentheses,
            ')' => rightParentheses,
            '+' => plus,
            '-' => minus,
            '*' => multiply,
            '/' => divide,
            '\n' => newLine,
            '.' => size,
            '#' => immediate,
            '$', '%', '@' => absolute,
            ';' => comment,
            'a'...'z', 'A'...'Z' => registerOrMnemonicOrLabel,
            '\'' => stringOrChar,
            '0'...'9' => absolute,
            else => null,
        };
    }
    break :map kvs;
};

pub fn init(text: []const u8, allocator: std.mem.Allocator) This {
    const tokens_len: usize = @intFromFloat(@ceil(@as(f64, @floatFromInt(text.len)) * 0.43));
    return .{
        .text = text,
        .tokens = std.ArrayList(Token).initCapacity(allocator, tokens_len) catch @panic("Could not allocate memory for lexing"),
    };
}

pub fn deinit(this: This) void {
    this.tokens.deinit();
}

pub fn scan(this: *This) []Token {
    while (this.position != this.text.len) {
        this.token_start = this.position;
        if (scan_map[this.consume()]) |scan_fn| scan_fn(this);
    }

    return this.tokens.items;
}

inline fn consume(this: *This) u8 {
    this.position += 1;
    return this.text[this.position - 1];
}

fn comma(this: *This) void {
    this.addToken(.comma);
}

fn addToken(this: *This, t: Token.Type) void {
    if (this.tokens.capacity == this.tokens.items.len) @panic("TODO FIX ME (Branch predictor wrong)");

    const ptr = this.tokens.addOneAssumeCapacity();
    ptr.type = t;
    ptr.relative_string = this.computeRelativeString();
}

fn computeRelativeString(this: This) std.meta.FieldType(Token, std.meta.FieldEnum(Token).relative_string) {
    return .{ .offset = @intCast(this.token_start - this.line_start), .len = @intCast(this.position - this.token_start) };
}

fn leftParentheses(this: *This) void {
    this.addToken(.left_parentheses);
}

fn rightParentheses(this: *This) void {
    this.addToken(.right_parentheses);
}

fn plus(this: *This) void {
    this.addToken(.plus);
}

fn minus(this: *This) void {
    this.addToken(.minus);
}

fn multiply(this: *This) void {
    this.addToken(.multiply);
}

fn divide(this: *This) void {
    this.addToken(.divide);
}

fn newLine(this: *This) void {
    this.addTokenWithData(.new_line, .{ .number = this.line_start });
    this.line_number += 1;
    this.line_start = this.position;
}

fn size(this: *This) void {
    this.skipUntillDelimiter();
    const str = this.text[this.token_start..this.position];

    if (str.len != 2) @panic("report error");

    switch (str[1] | 0b00100000) {
        'b' => this.addToken(.byte_size),
        'w' => this.addToken(.word_size),
        'l' => this.addToken(.long_size),
        else => @panic("report error"), // TODO report error to user
    }
}

fn immediate(this: *This) void {
    this.position += @intFromBool(this.text[this.position] == '-');
    this.position += @intFromBool(this.text[this.position] == '$' or this.text[this.position] == '%' or this.text[this.position] == '@');
    this.skipUntillDelimiter();

    if (fmt.parseSigned(this.text[this.token_start + 1 .. this.position])) |value| {
        this.addTokenWithData(.immediate, .{ .number = value });
    } else |err| switch (err) {
        std.fmt.ParseIntError.InvalidCharacter => this.addToken(.immediate_label),
        std.fmt.ParseIntError.Overflow => @panic("TODO REPORT ERROR"), // TODO REPORT ERROR
    }
}

inline fn skip(this: *This) void {
    this.position += 1;
}

inline fn addTokenWithData(this: *This, t: Token.Type, data: Token.Data) void {
    if (this.tokens.capacity == this.tokens.items.len) @panic("TODO FIX ME (Branch predictor wrong)");
    this.tokens.appendAssumeCapacity(.{ .type = t, .data = data, .relative_string = this.computeRelativeString() });
}

fn skipUntillDelimiter(this: *This) void {
    while (not_delimiter_map.isSet(this.peek())) {
        this.skip();
    }
}

inline fn peek(this: This) u8 {
    std.debug.assert(this.position < this.text.len);
    return this.text[this.position];
}

fn comment(this: *This) void {
    while (this.position != this.text.len and this.consume() != '\n') {}
    this.newLine();
}

fn registerOrMnemonicOrLabel(this: *This) void {
    this.skipUntillDelimiter();
    const str = this.text[this.token_start..this.position];

    if (this.parseRegister(str)) return;

    if (Token.mnemonicStrToType(str)) |mnemonic| {
        this.addToken(mnemonic);
        return;
    }

    this.addToken(.label);
}

fn parseRegister(this: *This, str: []const u8) bool {
    if (str.len != 2) return false;
    const num = std.fmt.parseUnsigned(u8, str[1..], 10) catch return false;

    const t = switch (str[0] | 0b00100000) {
        'd' => Token.Type.data_register,
        'a' => Token.Type.address_register,
        else => return false,
    };

    this.addTokenWithData(t, .{ .byte = num });
    return true;
}

fn stringOrChar(this: *This) void {
    while (this.position < this.text.len and this.consume() != '\'') {}
    const str = this.text[this.token_start..this.position];

    switch (str.len) {
        0...2 => @panic("wtf"), // TODO REPORT ERROR
        3 => this.addTokenWithData(.char, .{ .byte = str[1] }),
        else => this.addToken(.string),
    }
}

fn absolute(this: *This) void {
    this.skipUntillDelimiter();

    if (fmt.parseUnsigned(this.text[this.token_start..this.position])) |value| {
        this.addTokenWithData(.absolute, .{ .number = value });
    } else |_| @panic("report error"); //TODO report error
}
