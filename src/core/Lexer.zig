const std = @import("std");
const token = @import("token");
const fmt = @import("fmt");
const PerfectMap = @import("PerfectMap");

const This = @This();

pub const OutputQueue = @import("SwapQueue").create(token.Info, 80);

text: []const u8,
tokens: OutputQueue,
token_start: u32 = 0,
line_number: u32 = 0,
line_start: u32 = 0,
position: u32 = 0,

const InputError = error{
    Generic,
};

const mnemonic_map = mnmap: {
    const mnemonics = token.Type.mnemonicsAsKeyValues();
    const seed, const sz = PerfectMap.bruteforceSeedAndSize(mnemonics);
    break :mnmap PerfectMap.create(seed, sz, mnemonics);
};

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
    var kvs: [std.math.maxInt(u8) + 1]?*const fn (*This) InputError!void = undefined;

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
        if (scan_map[this.consume()]) |scan_fn| {
            scan_fn(this) catch |err|
                std.io.getStdErr().writer().print("Error Line:{}\n{s}:{s}\n", .{ this.line_number + 1, @errorName(err), this.text[this.token_start..this.position] }) catch {};
        }
    }

    this.tokens.endProduction();
}

fn comma(this: *This) InputError!void {
    this.addToken(.comma);
}

fn absoluteOrAddressingOrMath(this: *This) InputError!void {
    this.position = this.token_start;

    const displacement_or_number = this.getNumber(i64) catch |err| switch (err) {
        fmt.Error.InvalidCharacter => if (this.text[this.token_start] == '-' and this.text[this.token_start + 1] == '(') -1 else {
            this.position += 1;
            return InputError.Generic;
        },
        else => {
            this.position += 1;
            return InputError.Generic;
        },
    };

    if (this.peek() != '(') {
        const number: u32 = @truncate(@as(u64, @bitCast(displacement_or_number)));
        this.addTokenWithData(.absolute, .{ .Number = number });
        return;
    }

    this.skip();
    this.skipWhiteSpaces();

    if (this.getRegister()) |address_register| {
        if (address_register.type != .An) return InputError.Generic;
        const displacement = std.math.cast(i16, displacement_or_number) orelse return InputError.Generic;

        switch (displacement) {
            -1 => this.addTokenWithData(.@"-(An)", address_register.data),
            1 => this.addTokenWithData(.@"(An)+", address_register.data),
            else => this.addTokenWithData(.@"(d,An)", .{ .SimpleAddressing = .{ .register = address_register.data.Register, .displacement = displacement } }),
        }

        this.skipWhiteSpaces();
        if (this.consume() != ')') return InputError.Generic;
        return;
    }

    this.math();
}

fn addressingOrMath(this: *This) InputError!void {
    const displacement: i16 = d: {
        this.skipWhiteSpaces();

        if (this.getNumber(i16)) |n| {
            this.skipWhiteSpaces();

            if (this.consume() != ',') {
                this.math();
                return;
            }

            break :d n;
        } else |_| {
            this.position = this.token_start + 1;
            break :d 0;
        }
    };

    this.skipWhiteSpaces();

    if (this.getRegister()) |address_register| {
        if (address_register.type != .An) return InputError.Generic;
        this.skipWhiteSpaces();

        switch (this.consume()) {
            ')' => {
                if (displacement == 0) {
                    const is_post_incr = this.peek() == '+';
                    this.position += @intFromBool(is_post_incr);
                    this.addTokenWithData(if (is_post_incr) .@"(An)+" else .@"(An)", address_register.data);
                } else {
                    this.addTokenWithData(.@"(d,An)", .{ .SimpleAddressing = .{ .register = address_register.data.Register, .displacement = displacement } });
                }
            },
            ',' => {
                this.skipWhiteSpaces();
                const index_register = this.getRegister() orelse return InputError.Generic;

                this.addTokenWithData(.@"(d,An,Xi)", .{ .ComplexAddressing = .{
                    .displacement = displacement,
                    .address_register = address_register.data.Register,
                    .index_type = if (index_register.type == .An) .address else .data,
                    .index_register = index_register.data.Register,
                } });

                this.skipWhiteSpaces();
                if (this.consume() != ')') return InputError.Generic;
            },

            else => return InputError.Generic,
        }
    } else return InputError.Generic;
}

fn newLine(this: *This) InputError!void {
    this.addTokenWithData(.new_line, .{ .Number = this.line_start });
    this.line_number += 1;
    this.line_start = this.position;
}

fn size(this: *This) InputError!void {
    this.skipUntilDelimiter();
    const str = this.text[this.token_start..this.position];

    if (str.len != 2) return InputError.Generic;

    switch (str[1] | 0x20) {
        'b' => this.addToken(.B),
        'w' => this.addToken(.W),
        'l' => this.addToken(.L),
        else => return InputError.Generic,
    }
}

fn immediate(this: *This) InputError!void {
    if (this.getNumber(i64)) |n| {
        this.addTokenWithData(.immediate, .{ .Number = @truncate(@as(u64, @bitCast(n))) });
    } else |err| switch (err) {
        fmt.Error.InvalidCharacter => this.addToken(.immediate_label),
        fmt.Error.Overflow => return InputError.Generic,
    }
}

fn comment(this: *This) InputError!void {
    while (this.position != this.text.len and this.consume() != '\n') {}
    try this.newLine();
}

fn registerOrMnemonicOrLabel(this: *This) InputError!void {
    this.skipUntilDelimiter();
    const str = this.text[this.token_start..this.position];

    if (registerFromString(str)) |reg| {
        this.addTokenWithData(reg.type, reg.data);
    } else if (mnemonic_map.get(str)) |mnemonic| {
        this.addToken(mnemonic);
    } else this.addToken(.label);
}

fn stringOrChar(this: *This) InputError!void {
    while (this.position != this.text.len and this.consume() != '\'') {}
    const str = this.text[this.token_start..this.position];

    switch (str.len) {
        0...2 => return InputError.Generic,
        3 => this.addTokenWithData(.char, .{ .Char = str[1] }),
        else => this.addToken(.string),
    }
}

fn unexpectedToken(_: *This) InputError!void {
    return InputError.Generic;
}

fn math(_: *This) void {
    @panic("math not supported");
}

fn addToken(this: *This, t: token.Type) void {
    this.tokens.produce(.{ .type = t, .data = undefined, .relative_string = this.computeRelativeString() });
}

inline fn addTokenWithData(this: *This, t: token.Type, data: token.Data) void {
    this.tokens.produce(.{ .type = t, .data = data, .relative_string = this.computeRelativeString() });
}

fn computeRelativeString(this: This) std.meta.FieldType(token.Info, .relative_string) {
    return .{ .offset = @intCast(this.token_start - this.line_start), .len = @intCast(this.position - this.token_start) };
}

inline fn consume(this: *This) u8 {
    this.position += 1;
    return this.text[this.position - 1];
}

inline fn peek(this: This) u8 {
    return this.text[this.position];
}

fn skipUntilDelimiter(this: *This) void {
    while (this.position != this.text.len and not_delimiter_map.isSet(this.peek())) {
        this.skip();
    }
}

inline fn skip(this: *This) void {
    this.position += 1;
}

fn skipWhiteSpaces(this: *This) void {
    var c = this.peek();
    while (this.position != this.text.len and (c == ' ' or c == '\t' or c == '\n' or c == '\r')) : (c = this.peek()) {
        this.skip();
    }
}

inline fn getRegister(this: *This) ?token.Info {
    const start = this.position;
    this.skipUntilDelimiter();

    return registerFromString(this.text[start..this.position]);
}

fn registerFromString(str: []const u8) ?token.Info {
    if (str.len != 2) return null;
    const num = std.fmt.parseUnsigned(u3, str[1..], 10) catch return null;

    const t = switch (str[0] | 0x20) {
        'd' => token.Type.Dn,
        'a' => token.Type.An,
        else => return null,
    };

    return .{ .type = t, .data = .{ .Register = num }, .relative_string = undefined };
}

inline fn getNumber(this: *This, comptime T: type) fmt.Error!T {
    const start = this.position;

    this.position += @intFromBool(this.peek() == '-');
    this.position += switch (this.peek()) {
        '%', '@', '$' => 1,
        else => 0,
    };
    this.skipUntilDelimiter();

    return numberFromString(T, this.text[start..this.position]);
}

fn numberFromString(comptime T: type, str: []const u8) !T {
    return fmt.parse(T, str);
}
