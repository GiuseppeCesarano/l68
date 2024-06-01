const std = @import("std");
const Token = @import("token.zig").Token;

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

const mnemonics_map = std.ComptimeStringMap(Token, kvs_list: {
    const mnemonics = Token.mnemonics();
    var list: [mnemonics.len]struct { []const u8, Token } = undefined;
    for (&list, mnemonics) |*elm, mnemonic| {
        elm.* = @TypeOf(list[0]){ mnemonic.name, @unionInit(Token, mnemonic.name, {}) };
    }
    break :kvs_list list;
});

const scan_map = map: {
    var kvs: [256]*const fn (*This) void = undefined;
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
            'a'...'z', 'A'...'Z' => registerOrMenmonicOrLabel,
            '\'' => stringOrChar,
            '0'...'9' => absolute,
            else => noop,
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
        scan_map[this.consume()](this);
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
    switch (str[1]) {
        'b', 'B' => this.addToken(.byte_size),
        'w', 'W' => this.addToken(.word_size),
        'l', 'L' => this.addToken(.long_size),
        else => @panic("report error"), // TODO report error to user
    }
}

inline fn peekPlusOffset(this: This, offset: u32) u8 {
    return if (this.position + offset < this.text.len) this.text[this.position + offset] else 0;
}

inline fn peek(this: This) u8 {
    return this.peekPlusOffset(0);
}

fn immediate(this: *This) void {
    const is_negative = this.skipIfEql('-');
    const base = this.consumeIfBase();
    this.skipUntillDelimiter();
    const str = this.text[this.token_start_postion + 1 + @intFromBool(is_negative) + @intFromBool(base != 10 and base != null) .. this.position];
    if (base) |b| {
        if (std.fmt.parseInt(i64, str, b)) |value| {
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
        ' ', '0'...'9' => {
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
    while (this.position != this.text.len) {
        switch (this.peek()) {
            'a'...'z', 'A'...'Z', '0'...'9', '_' => this.skip(),
            else => break,
        }
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
    if (std.fmt.parseInt(u32, str, base)) |value| {
        this.addToken(.{ .absolute = value });
    } else |_| @panic("report error"); //TODO report error
}

fn comment(this: *This) void {
    while (this.position != this.text.len and this.consume() != '\n') {}
    this.newLine();
}

fn registerOrMenmonicOrLabel(this: *This) void {
    this.skipUntillDelimiter();
    const str = this.text[this.token_start_postion..this.position];
    this.addToken(parseRegister(str) orelse parseMnemonic(str) orelse .{ .label = str });
}

fn parseRegister(str: []const u8) ?Token {
    if (str.len != 2) {
        return null;
    }
    const num = std.fmt.parseInt(u8, str[1..], 10) catch return null;
    return switch (str[0]) {
        'D', 'd' => .{ .data_register = num },
        'A', 'a' => .{ .address_register = num },
        else => return null,
    };
}

fn parseMnemonic(str: []const u8) ?Token {
    const max_len = mnemonics_map.kvs[mnemonics_map.kvs.len - 1].key.len;
    if (str.len > max_len) {
        return null;
    }
    var lowercase_str: [max_len]u8 = undefined;
    toLower(&lowercase_str, str);
    return mnemonics_map.get(lowercase_str[0..str.len]);
}

fn toLower(dest: []u8, str: []const u8) void {
    std.mem.copyForwards(u8, dest, str);
    for (dest) |*c| {
        c.* |= 0b00100000;
    }
}

fn stringOrChar(this: *This) void {
    while (this.position != this.text.len and this.consume() != '\'') {}
    const str = this.text[this.token_start_postion..this.position];
    if (str.len < 3) @panic("wtf"); // TODO REPORT ERROR
    this.addToken(if (str.len == 3) .{ .char = str[1] } else .{ .string = str });
}

fn noop(_: *This) void {}
