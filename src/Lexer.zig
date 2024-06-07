const std = @import("std");
const Token = @import("Token").Type;

const This = @This();
const TokenInfo = struct {
    token: Token,
    line: u32,
    row: u32,
};

text: []const u8,
tokens: std.ArrayList(TokenInfo),
token_start_postion: u32 = 0,
line_number: u32 = 0,
line_start_postion: u32 = 0,
position: u32 = 0,

const mnemonics_map = @import("Token").mnemonics_map;
const not_delimiter_map = blk: {
    const len = std.math.maxInt(u8) + 1;
    var bitset = std.bit_set.StaticBitSet(len).initEmpty();
    for (0..len) |index| {
        @setEvalBranchQuota(5000);
        bitset.setValue(index, switch (index) {
            'a'...'z', 'A'...'Z', '0'...'9', '_' => true,
            else => false,
        });
    }
    break :blk bitset;
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
    var tokens = std.ArrayList(TokenInfo).init(allocator);
    const expected_tokens_len: usize = @intFromFloat(@ceil(@as(f64, @floatFromInt(text.len)) * 0.4));
    tokens.ensureTotalCapacity(expected_tokens_len) catch @panic("Could not allocate memory for lexing");
    return .{ .text = text, .tokens = tokens };
}

pub fn deinit(this: This) void {
    this.tokens.deinit();
}

pub fn scanTokens(this: *This) []TokenInfo {
    while (this.position != this.text.len) {
        this.token_start_postion = this.position;
        if (scan_map[this.consume()]) |scan_fn| scan_fn(this);
    }

    return this.tokens.items;
}

inline fn consume(this: *This) u8 {
    const char = this.text[this.position];
    this.position += 1;
    return char;
}

fn comma(this: *This) void {
    this.addToken(.comma);
}

fn addToken(this: *This, t: Token) void {
    this.tokens.append(.{
        .token = t,
        .line = this.line_number,
        .row = this.position - this.line_start_postion,
    }) catch @panic("Could not allocate memory for lexing");
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
    this.line_number += 1;
    this.line_start_postion = this.position;
}

fn size(this: *This) void {
    this.skipUntillDelimiter();
    const str = this.text[this.token_start_postion..this.position];
    if (str.len != 2) @panic("report error");
    switch (str[1] | 0b00100000) {
        'b' => this.addToken(.byte_size),
        'w' => this.addToken(.word_size),
        'l' => this.addToken(.long_size),
        else => @panic("report error"), // TODO report error to user
    }
}

inline fn peek(this: This) u8 {
    return if (this.position != this.text.len) this.text[this.position] else 0;
}

fn immediate(this: *This) void {
    const is_negative = this.skipIfEql('-');
    const base = this.consumeIfBase();
    this.skipUntillDelimiter();
    const offset: usize = 1 + @as(usize, @intFromBool(is_negative)) + @intFromBool(base != 10 and base != null);
    const str = this.text[this.token_start_postion + offset .. this.position];
    if (base) |b| {
        if (std.fmt.parseUnsigned(i64, str, b)) |value| {
            this.addToken(.{ .immediate = value * @as(i64, if (is_negative) -1 else 1) });
        } else |_| @panic("report error"); //TODO report
    } else this.addToken(.{ .immediate_label = str });
}

inline fn skipIfEql(this: *This, c: u8) bool {
    const is_eql = c == this.peek();
    this.position += @intFromBool(is_eql);
    return is_eql;
}

inline fn skip(this: *This) void {
    this.position += 1;
}

fn consumeIfBase(this: *This) ?u8 {
    switch (this.peek()) {
        '%' => {
            this.skip();
            return 2;
        },
        '@' => {
            this.skip();
            return 8;
        },
        '0'...'9' => {
            this.skip();
            return 10;
        },
        '$' => {
            this.skip();
            return 16;
        },
        else => return null,
    }
}

fn skipUntillDelimiter(this: *This) void {
    while (not_delimiter_map.isSet(this.peek())) {
        this.skip();
    }
}

fn absolute(this: *This) void {
    this.position -= 1;
    const base = this.consumeIfBase() orelse b: {
        this.skip();
        break :b 10;
    };
    this.skipUntillDelimiter();
    const str = this.text[this.token_start_postion + @intFromBool(base != 10) .. this.position];
    if (std.fmt.parseUnsigned(u32, str, base)) |value| {
        this.addToken(.{ .absolute = value });
    } else |_| @panic("report error"); //TODO report error
}

fn comment(this: *This) void {
    while (this.position != this.text.len and this.consume() != '\n') {}
    this.newLine();
}

fn registerOrMnemonicOrLabel(this: *This) void {
    this.skipUntillDelimiter();
    const str = this.text[this.token_start_postion..this.position];
    this.addToken(parseRegister(str) orelse mnemonics_map.get(str) orelse .{ .label = str });
}

fn parseRegister(str: []const u8) ?Token {
    if (str.len != 2) return null;
    const num = std.fmt.parseUnsigned(u8, str[1..], 10) catch return null;
    return switch (str[0] | 0b00100000) {
        'd' => .{ .data_register = num },
        'a' => .{ .address_register = num },
        else => null,
    };
}

fn stringOrChar(this: *This) void {
    while (this.position != this.text.len and this.consume() != '\'') {}
    const str = this.text[this.token_start_postion..this.position];
    if (str.len < 3) @panic("wtf"); // TODO REPORT ERROR
    this.addToken(if (str.len == 3) .{ .char = str[1] } else .{ .string = str });
}

fn noop(_: *This) void {}
