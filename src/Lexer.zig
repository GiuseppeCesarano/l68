const std = @import("std");
const Token = @import("Token");
const fmt = @import("helpers").fmt;

const This = @This();

pub const OutputQueue = @import("helpers").SwapQueue(Token, 50);

text: []const u8,
tokens: OutputQueue,
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
            '-' => absoluteOrAddressingOrMath,
            '(' => addressingOrMath,
            '+' => absoluteOrAddressingOrMath,
            '\n' => newLine,
            '.' => size,
            '#' => immediate,
            '$', '%', '@' => absoluteOrAddressingOrMath,
            ';' => comment,
            'a'...'z', 'A'...'Z' => registerOrMnemonicOrLabel,
            '\'' => stringOrChar,
            '0'...'9' => absoluteOrAddressingOrMath,
            ' ', '\t', '\r' => null,
            else => unexpectedToken,
        };
    }

    break :map kvs;
};

pub fn init(text: []const u8) This {
    return .{ .text = text, .tokens = OutputQueue.init() };
}

pub fn deinit(_: This) void {}

pub fn scan(this: *This) void {
    while (this.position != this.text.len) {
        this.token_start = this.position;
        if (scan_map[this.consume()]) |scan_fn| scan_fn(this);
    }

    this.tokens.endProduction();
}

fn comma(this: *This) void {
    this.addToken(.comma);
}

fn absoluteOrAddressingOrMath(this: *This) void {
    this.position = this.token_start;
    const numOrDisplacement = this.number() catch |err| switch (err) {
        std.fmt.ParseIntError.InvalidCharacter => @as(u32, @bitCast(@as(i32, -1))),
        else => @panic("???"),
    };

    if (this.peek() != '(') {
        this.addTokenWithData(.absolute, .{ .Number = numOrDisplacement });

        return;
    }

    this.skip();
    if (this.register()) |address_register| {
        const displacement: i16 = @bitCast(@as(u16, @intCast(0x0000FFFF & numOrDisplacement)));
        switch (displacement) {
            -1 => this.addTokenWithData(.@"-(An)", address_register.data),
            1 => this.addTokenWithData(.@"(An)+", address_register.data),
            else => this.addTokenWithData(.@"(d,An)", .{ .SimpleAddressing = .{
                .register = address_register.data.Register,
                .displacement = displacement,
            } }),
        }

        this.skipWhiteSpaces();
        if (this.consume() != ')') @panic("addressing malformed");

        return;
    }

    this.math();
}

fn addressingOrMath(this: *This) void {
    const displacement_or_null: ?i16 = d: {
        this.skipWhiteSpaces();
        if (this.number()) |n| {
            this.skipWhiteSpaces();
            if (this.consume() != ',') {
                this.math();
                return;
            }
            break :d @bitCast(@as(u16, @intCast(n & 0x0000FFFFF)));
        } else |_| {
            this.position = this.token_start + 1;
            break :d null;
        }
    };

    if (this.register()) |address_register| {
        this.skipWhiteSpaces();
        switch (this.consume()) {
            ')' => {
                if (displacement_or_null) |displacement| {
                    this.addTokenWithData(.@"(d,An)", .{ .SimpleAddressing = .{
                        .register = address_register.data.Register,
                        .displacement = displacement,
                    } });
                } else {
                    const is_post_incr = this.peek() == '+';
                    this.position += @intFromBool(is_post_incr);
                    this.addTokenWithData(if (is_post_incr) .@"(An)+" else .@"(An)", address_register.data);
                }
            },
            ',' => {
                const index_register = this.register() orelse @panic("Addressing malformed");
                this.addTokenWithData(.@"(d,An,Xi)", .{ .ComplexAddressing = .{
                    .displacement = displacement_or_null orelse 0,
                    .address_register = address_register.data.Register,
                    .index_type = if (index_register.type == .An) .address else .data,
                    .index_register = index_register.data.Register,
                } });

                this.skipWhiteSpaces();
                if (this.consume() != ')') @panic("Addressing malformed");
            },

            else => @panic("addressing malformed"),
        }

        return;
    }

    this.math();
}

fn newLine(this: *This) void {
    this.addTokenWithData(.new_line, .{ .Number = this.line_start });
    this.line_number += 1;
    this.line_start = this.position;
}

fn size(this: *This) void {
    this.skipUntilDelimiter();
    const str = this.text[this.token_start..this.position];

    if (str.len != 2) @panic("report error");

    switch (str[1] | 0x20) {
        'b' => this.addToken(.B),
        'w' => this.addToken(.W),
        'l' => this.addToken(.L),
        else => @panic("report error"),
    }
}

fn immediate(this: *This) void {
    if (this.number()) |n| {
        this.addTokenWithData(.immediate, .{ .Number = n });
    } else |err| switch (err) {
        std.fmt.ParseIntError.InvalidCharacter => this.addToken(.immediate_label),
        std.fmt.ParseIntError.Overflow => @panic("TODO REPORT ERROR"),
    }
}

fn comment(this: *This) void {
    while (this.position != this.text.len and this.consume() != '\n') {}
    this.newLine();
}

fn registerOrMnemonicOrLabel(this: *This) void {
    this.skipUntilDelimiter();
    const str = this.text[this.token_start..this.position];

    if (tryRegister(str)) |reg| {
        this.addTokenWithData(reg.type, reg.data);
    } else if (Token.mnemonicStrToType(str)) |mnemonic| {
        this.addToken(mnemonic);
    } else this.addToken(.label);
}

fn stringOrChar(this: *This) void {
    while (this.position < this.text.len and this.consume() != '\'') {}
    const str = this.text[this.token_start..this.position];

    switch (str.len) {
        0...2 => @panic("wtf"),
        3 => this.addTokenWithData(.char, .{ .Char = str[1] }),
        else => this.addToken(.string),
    }
}

fn unexpectedToken(_: *This) void {
    @panic("Token not expected");
}

inline fn consume(this: *This) u8 {
    this.position += 1;
    return this.text[this.position - 1];
}

fn addToken(this: *This, t: Token.Type) void {
    const ptr = this.tokens.addOne();
    ptr.type = t;
    ptr.relative_string = this.computeRelativeString();
}

fn computeRelativeString(this: This) std.meta.FieldType(Token, std.meta.FieldEnum(Token).relative_string) {
    return .{ .offset = @intCast(this.token_start - this.line_start), .len = @intCast(this.position - this.token_start) };
}

inline fn peek(this: This) u8 {
    std.debug.assert(this.position < this.text.len);
    return this.text[this.position];
}

inline fn register(this: *This) ?Token {
    this.skipWhiteSpaces();

    const key_start = this.position;
    this.skipUntilDelimiter();

    return tryRegister(this.text[key_start..this.position]);
}

fn skipWhiteSpaces(this: *This) void {
    var c = this.peek();
    while (c == ' ' or c == '\t' or c == '\n' or c == '\r') : (c = this.peek()) {
        this.skip();
    }
}

fn skipUntilDelimiter(this: *This) void {
    while (not_delimiter_map.isSet(this.peek())) {
        this.skip();
    }
}

fn tryRegister(str: []const u8) ?Token {
    if (str.len != 2) return null;
    const num = std.fmt.parseUnsigned(u3, str[1..], 10) catch return null;

    const t = switch (str[0] | 0x20) {
        'd' => Token.Type.Dn,
        'a' => Token.Type.An,
        else => return null,
    };

    return .{ .type = t, .data = .{ .Register = num }, .relative_string = undefined };
}

inline fn number(this: *This) !u32 {
    const key_start = this.position;

    this.position += @intFromBool(this.peek() == '-');
    this.position += switch (this.peek()) {
        '%', '@', '$' => 1,
        else => 0,
    };
    this.skipUntilDelimiter();

    return tryNumber(this.text[key_start..this.position]);
}

fn math(_: *This) void {}

inline fn tryNumber(str: []const u8) !u32 {
    return fmt.parseSigned(u32, str);
}

inline fn skip(this: *This) void {
    this.position += 1;
}

inline fn addTokenWithData(this: *This, t: Token.Type, data: Token.Data) void {
    this.tokens.produce(.{ .type = t, .data = data, .relative_string = this.computeRelativeString() });
}
