const std = @import("std");
const Token = @import("types.zig").Token;
const report = @import("report.zig");

const This = @This();

text: []const u8,
tokens: std.ArrayList(Token),

line_num: usize = 0,
next: usize = 0,
start: usize = 0,

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
    return .{ .text = text, .tokens = std.ArrayList(Token).init(allocator), .buffer = std.ArrayList(u8).init(allocator) };
}

pub fn deinit(this: This) void {
    this.tokens.deinit();
    this.buffer.deinit();
}

pub fn scanTokens(this: *This) @TypeOf(this.tokens) {
    while (this.next != this.text.len) {
        this.start = this.next;
        this.scanToken();
    }

    return this.tokens;
}

fn scanToken(this: *This) void {
    const char = this.consume();
    const token: ?Token = switch (char) {
        ',' => .comma,
        '(' => .left_parentheses,
        '-' => if (this.consumeIfEql('(')) .minus_left_parentheses else null,
        ')' => if (this.consumeIfEql('+')) .right_parentheses_plus else .right_parentheses,
        '.' => this.size(),
        '#' => this.number(),
        '$' => this.ram(),
        ';' => this.comment(),
        'a'...'z', 'A'...'Z' => this.identifier(),
        '\'' => this.string(),
        '0'...'9' => this.ram(),
        '\n' => this.newLine(),
        ' ', '\t', '\r' => return,
        else => null,
    };

    if (token) |tk| {
        this.addToken(tk);
    } else {
        this.err();
    }
}

inline fn consume(this: *This) u8 {
    const char = this.text[this.next];
    this.next += 1;
    return char;
}

fn addToken(this: *This, token: Token) void {
    this.tokens.append(token) catch @panic("error"); //TODO: don't silent fail.
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

fn number(this: *This) ?Token {
    const has_leading_dollar = this.consumeIfEql('$');
    _ = this.consumeIfEql('-');
    if (has_leading_dollar) this.consumeUntillNotIdentifier() else this.consumeUntillNotDigit();
    const string_number = this.text[this.start + @intFromBool(has_leading_dollar) + 1 .. this.next];
    return .{
        .number = .{
            .value = std.fmt.parseInt(i64, string_number, if (has_leading_dollar) 16 else 10) catch return null,
            .is_hex = has_leading_dollar,
        },
    };
}

fn ram(this: *This) ?Token {
    const has_leading_dollar = this.text[this.start] == '$';
    if (has_leading_dollar) this.consumeUntillNotIdentifier() else this.consumeUntillNotDigit();
    const string_number = this.text[this.start + @intFromBool(has_leading_dollar) .. this.next];
    return .{
        .ram = .{
            .location = std.fmt.parseInt(u32, string_number, if (has_leading_dollar) 16 else 10) catch return null,
            .is_hex = has_leading_dollar,
        },
    };
}

fn consumeUntillNotDigit(this: *This) void {
    while (std.ascii.isDigit(this.peek())) {
        _ = this.consume();
    }
}

fn peek(this: This) u8 {
    return if (this.next < this.text.len) this.text[this.next] else 0;
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

fn identifier(this: *This) Token {
    this.consumeUntillNotIdentifier();
    const str = this.text[this.start..this.next];
    return this.register() orelse mnemonic_map.get(this.toLower(str)) orelse .{ .label = str };
}

fn consumeUntillNotIdentifier(this: *This) void {
    while (std.ascii.isAlphanumeric(this.peek()) or this.peek() == '_') {
        _ = this.consume();
    }
}

fn register(this: *This) ?Token {
    const str = this.text[this.start..this.next];
    if (str.len != 2 or !std.ascii.isDigit(str[1])) return null;
    return switch (str[0]) {
        'D', 'd' => .{ .data_register = str[1] - '0' },
        'A', 'a' => .{ .address_register = str[1] - '0' },
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

fn string(this: *This) Token {
    this.consumeUntill('\'');
    const str = this.text[this.start..this.next];
    return if (str.len == 1) .{ .char = str[0] } else .{ .string = str };
}

fn newLine(this: *This) Token {
    this.line_num += 1;
    return .{ .new_line = {} };
}

fn err(this: *This) void {
    const line, const column = this.tokenLineAndCol();
    report.unexpectedToken(line, this.line_num, column);
    this.deleteCurrentTokenLine();
    this.consumeUntill('\n');
    this.addToken(.{ .err_line = line });
}

fn tokenLineAndCol(this: This) struct { []const u8, usize } {
    var line_start = this.next;
    while (line_start - 1 > 0 and this.text[line_start - 1] != '\n') : (line_start -= 1) {}
    var line_end = this.next;
    while (this.text[line_end] != '\n' and line_end < this.text.len) : (line_end += 1) {}
    return .{ this.text[line_start..line_end], this.start - line_start };
}

fn deleteCurrentTokenLine(this: *This) void {
    var token = this.tokens.getLastOrNull();
    while (token != null and token.? != .new_line) : (token = this.tokens.getLastOrNull()) {
        _ = this.tokens.pop();
    }
}
