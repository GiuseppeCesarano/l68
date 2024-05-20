const std = @import("std");
const Token = @import("token.zig").Token;
const NumberBase = @import("token.zig").NumberBase;

const This = @This();

text: []const u8,
tokens: std.ArrayList(Token),
unknown_token_locations: std.ArrayList(u32),

line_count: u32 = 0,
next: u32 = 0,
start: u32 = 0,

buffer: std.ArrayList(u8), //TODO: Refactor if possible.

const mnemonic_map = std.ComptimeStringMap(Token, kvs_list: {
    const mnemonics = Token.mnemonics();
    var list: [mnemonics.len]struct { []const u8, Token } = undefined;
    for (&list, mnemonics) |*elm, mnemonic| {
        elm.* = @TypeOf(list[0]){ mnemonic.name, @unionInit(Token, mnemonic.name, {}) };
    }
    break :kvs_list list;
});

pub fn init(text: []const u8, allocator: std.mem.Allocator) This {
    return .{ .text = text, .tokens = std.ArrayList(Token).init(allocator), .unknown_token_locations = std.ArrayList(u32).init(allocator), .buffer = std.ArrayList(u8).init(allocator) };
}

pub fn deinit(this: This) void {
    this.tokens.deinit();
    this.unknown_token_locations.deinit();
    this.buffer.deinit();
}

pub fn scanTokens(this: *This) struct { @TypeOf(this.tokens.items), ?@TypeOf(this.unknown_token_locations.items) } {
    while (this.next != this.text.len) {
        this.start = this.next;
        this.scanToken();
    }
    return .{ this.tokens.items, if (this.unknown_token_locations.items.len != 0) this.unknown_token_locations.items else null };
}

fn scanToken(this: *This) void {
    const char = this.consume();
    const token: ?Token = switch (char) {
        ',' => .comma,
        '(' => .left_parentheses,
        '-' => if (this.consumeIfEql('(')) .minus_left_parentheses else this.immediate(), //TODO: handle correctly
        ')' => if (this.consumeIfEql('+')) .right_parentheses_plus else .right_parentheses,
        '.' => this.size(),
        '#' => this.immediate(),
        '$', '%', '@' => this.absolute(),
        ';' => this.comment(),
        'a'...'z', 'A'...'Z' => this.registerOrMenmonicOrLabel(),
        '\'' => this.stringOrChar(),
        '0'...'9' => this.absolute(),
        '\n' => this.newLine(),
        ' ', '\t', '\r' => return,
        else => null,
    };
    if (token) |tk| {
        this.tokens.append(tk) catch @panic("error"); //TODO: don't silent fail.
    } else {
        this.unknown_token_locations.append(this.start) catch @panic("error"); //TODO: don't panic
    }
}

inline fn consume(this: *This) u8 {
    const char = this.text[this.next];
    this.next += 1;
    return char;
}

fn consumeIfEql(this: *This, expected: u8) bool {
    const is_match = this.next < this.text.len and this.text[this.next] == expected;
    this.next += @intFromBool(is_match);
    return is_match;
}

fn size(this: *This) ?Token {
    this.consumeUntillNotIdentifier();
    if (this.next - this.start != 2) return null;
    return switch (this.text[this.start + 1]) {
        'b', 'B' => .byte_size,
        'w', 'W' => .word_size,
        'l', 'L' => .long_size,
        else => null,
    };
}

fn consumeUntillNotIdentifier(this: *This) void {
    while (std.ascii.isAlphanumeric(this.peek()) or this.peek() == '_') {
        _ = this.consume();
    }
}

fn peek(this: This) u8 {
    return if (this.next < this.text.len) this.text[this.next] else 0;
}

fn immediate(this: *This) ?Token {
    const value, const base = this.number() orelse return null;
    return .{ .immediate = .{ .value = value, .base = base } };
}

fn number(this: *This) ?struct { i64, NumberBase } {
    const number_base = this.consumeIfNumberBase() orelse .decimal;
    const has_leading_hash = this.text[this.start] == '#';
    this.consumeUntillNotDigit();
    const string_number = this.text[this.start + @intFromBool(number_base != .decimal) + @intFromBool(has_leading_hash) .. this.next];
    const base = @intFromEnum(number_base);
    return .{ std.fmt.parseInt(i64, string_number, base) catch return null, number_base };
}

fn consumeIfNumberBase(this: *This) ?NumberBase {
    return blk: {
        if (NumberBase.fromChar(this.peek())) |base| {
            _ = this.consume();
            break :blk base;
        } else |_| break :blk null;
    };
}

fn consumeUntillNotDigit(this: *This) void {
    var c = this.peek();
    while (isDigit(c)) : (c = this.peek()) {
        _ = this.consume();
    }
}

fn isDigit(c: u8) bool {
    return std.ascii.isDigit(c) or (c >= 'A' and c <= 'F') or (c >= 'a' and c <= 'f') or c == '-' or c == '+';
}

fn absolute(this: *This) ?Token {
    this.next = this.next - 1;
    const value, const base = this.number() orelse return null;
    return if (value >= 0) .{ .absolute = .{ .location = @intCast(value), .base = base } } else null;
}

fn comment(this: *This) Token {
    this.consumeUntill('\n');
    return .{ .comment = this.text[this.start..this.next] };
}

fn consumeUntill(this: *This, char: u8) void {
    while (this.next < this.text.len and this.peek() != char) {
        _ = this.consume();
    }
}

fn registerOrMenmonicOrLabel(this: *This) Token {
    this.consumeUntillNotIdentifier();
    const str = this.text[this.start..this.next];
    return this.tryRegister() orelse mnemonic_map.get(this.toLower(str)) orelse .{ .label = str };
}

fn tryRegister(this: *This) ?Token {
    const str = this.text[this.start..this.next];
    const register_number = std.fmt.parseInt(u8, str[1..1], 10) catch return null;
    if (str.len != 2 or register_number > 7) return null;
    return switch (str[0]) {
        'D', 'd' => .{ .data_register = register_number },
        'A', 'a' => .{ .address_register = register_number },
        else => null,
    };
}

fn toLower(this: *This, str: []const u8) []u8 {
    if (str.len > this.buffer.capacity) {
        this.buffer.ensureTotalCapacity(str.len) catch @panic("error"); //TODO: Handle better.
        this.buffer.expandToCapacity();
    }
    for (str, 0..) |char, i| {
        this.buffer.items[i] = std.ascii.toLower(char);
    }
    return this.buffer.items[0..str.len];
}

fn stringOrChar(this: *This) Token {
    this.consumeUntill('\'');
    const str = this.text[this.start..this.next];
    return if (str.len == 1) .{ .char = str[0] } else .{ .string = str };
}

fn newLine(this: *This) Token {
    this.line_count += 1;
    return .new_line;
}
