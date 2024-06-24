const std = @import("std");
const Token = @import("Token");

const This = @This();

text: []const u8,
tokens: Token.List(),
token_start_postion: u32 = 0,
line_number: u32 = 0,
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
    return .{
        .text = text,
        .tokens = Token.List().init(allocator, text.len) catch @panic("Could not allocate memory for lexing."),
    };
}

pub fn deinit(this: This) void {
    this.tokens.deinit();
}

pub fn scanTokens(this: *This) []Token {
    while (this.position != this.text.len) {
        this.token_start_postion = this.position;
        if (scan_map[this.consume()]) |scan_fn| scan_fn(this);
    }
    return this.tokens.items();
}

inline fn consume(this: *This) u8 {
    const char = this.text[this.position];
    this.position += 1;
    return char;
}

fn comma(this: *This) void {
    this.addOnlyTokenType(.comma);
}

inline fn addOnlyTokenType(this: *This, t: Token.Type) void {
    this.tokens.addOnlyTokneType(
        t,
        this.computeLocation(),
    );
}

inline fn computeLocation(this: This) Token.Location {
    return .{
        .line = this.line_number,
        .row = this.token_start_postion,
        .len = @intCast(this.position - this.token_start_postion),
    };
}

fn leftParentheses(this: *This) void {
    this.addOnlyTokenType(.left_parentheses);
}

fn rightParentheses(this: *This) void {
    this.addOnlyTokenType(.right_parentheses);
}

fn plus(this: *This) void {
    this.addOnlyTokenType(.plus);
}

fn minus(this: *This) void {
    this.addOnlyTokenType(.minus);
}

fn multiply(this: *This) void {
    this.addOnlyTokenType(.multiply);
}

fn divide(this: *This) void {
    this.addOnlyTokenType(.divide);
}

fn newLine(this: *This) void {
    this.line_number += 1;
}

fn size(this: *This) void {
    this.skipUntillDelimiter();
    const str = this.text[this.token_start_postion..this.position];
    if (str.len != 2) @panic("report error");
    switch (str[1] | 0b00100000) {
        'b' => this.addOnlyTokenType(.byte_size),
        'w' => this.addOnlyTokenType(.word_size),
        'l' => this.addOnlyTokenType(.long_size),
        else => @panic("report error"), // TODO report error to user
    }
}

inline fn peek(this: This) u8 {
    std.debug.assert(this.position < this.text.len);
    return this.text[this.position];
}

fn immediate(this: *This) void {
    const is_negative = this.skipIfEql('-');
    const base = this.consumeIfBase();
    this.skipUntillDelimiter();
    const offset: usize = 1 + @as(usize, @intFromBool(is_negative)) + @intFromBool(base != 10 and base != null);
    const str = this.text[this.token_start_postion + offset .. this.position];
    if (base) |b| {
        if (std.fmt.parseUnsigned(u32, str, b)) |value| {
            if (is_negative) this.addOnlyTokenType(.minus);
            this.addTokenWithData(.immediate, .{ .number = value });
        } else |_| @panic("report error"); //TODO report
    } else this.addTokenWithString(.immediate_label, str);
}

inline fn addTokenWithData(this: *This, t: Token.Type, data: Token.Data) void {
    this.tokens.addTokenWithData(t, this.computeLocation(), data);
}

inline fn addTokenWithString(this: *This, t: Token.Type, str: []const u8) void {
    this.tokens.addTokenWithString(t, this.computeLocation(), str);
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
        this.addTokenWithData(.absolute, .{ .number = value });
    } else |_| @panic("report error"); //TODO report error
}

fn comment(this: *This) void {
    while (this.position != this.text.len and this.consume() != '\n') {}
    this.newLine();
}

fn registerOrMnemonicOrLabel(this: *This) void {
    this.skipUntillDelimiter();
    const str = this.text[this.token_start_postion..this.position];
    if (this.parseRegister(str)) return;
    if (Token.mnemonicStrToType(str)) |mnemonic| {
        this.addOnlyTokenType(mnemonic);
        return;
    }
    this.addTokenWithString(.label, str);
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
    while (this.position != this.text.len and this.consume() != '\'') {}
    const str = this.text[this.token_start_postion..this.position];
    if (str.len < 3) @panic("wtf"); // TODO REPORT ERROR
    if (str.len == 3) {
        this.addTokenWithData(.char, .{ .byte = str[1] });
    } else {
        this.addTokenWithString(.string, str);
    }
}
