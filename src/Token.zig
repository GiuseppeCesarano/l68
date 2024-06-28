const std = @import("std");

pub const Location = struct {
    line: u32,
    row: u32,
    len: u16,
};

pub const Data = union {
    number: u32,
    index: u32,
    byte: u8,
};

pub const Type = enum(u8) {
    // Literals
    label,
    immediate,
    immediate_label,
    absolute,
    char,
    string,

    // Single charchater tokens
    comma,
    left_parentheses,
    right_parentheses,
    plus,
    minus,
    multiply,
    divide,

    // Dual charchater tokens
    byte_size,
    word_size,
    long_size,
    data_register,
    address_register,

    // mnemonics (must be ketp sequential)
    // zig fmt: off
    abcd, add, adda, addi, addq, @"and", andi, asl, asr,
    bcc, bchg, bclr, bra, bset, bsr, btst,
    chk, clr,
    cmp, cmpa, cmpi, cmpm,
    dbcc, dc, dcb, divs, ds,
    end, eor, eori, equ, exg, ext,
    illegal,
    jmp, jsr, 
    lea, link, lsl, lsr,
    move, movea, movep, moveq, muls, mulu,
    nbcd, neg, negx, nop, not,
    org, ori, orr,
    pea, 
    reg, reset, rol, ror, roxl, roxr, rte, rtr, rts, 
    sbcd, scc, set, stop, sub, suba, subi, subq, subx, swap,
    tas, trap, trapv, tst,
    unlk,
    // zig fmt: on

    pub fn mnemonics() []const std.builtin.Type.EnumField {
        return @typeInfo(@This()).Enum.fields[@intFromEnum(@This().abcd)..];
    }
};

const mnemonics_map = struct {
    const Whole = u56;
    const Part = u32;
    const Entry = packed struct {
        whole: Whole,
        type: Type,
    };

    const table = table: {
        for (1..35) |size_multiplier| {
            const possible_table = generateSizedTableWithSeed(Type.mnemonics().len * size_multiplier);
            if (possible_table) |tbl| break :table .{ .data = tbl[0], .seed = tbl[1] };
        }
        @compileError("mnemonics_map's size multiplier > 35");
    };

    fn generateSizedTableWithSeed(comptime size: usize) ?struct { [size]Entry, u32 } {
        const mnemonics = Type.mnemonics();
        for (0..15000) |seed| {
            @setEvalBranchQuota(std.math.maxInt(u32));
            var data = [_]Entry{.{ .whole = 0, .type = undefined }} ** size;
            for (mnemonics) |mnemonic| {
                const whole, const part = encodeWholeAndPart(mnemonic.name);
                const i = hash(part, seed, size);
                if (data[i].whole != 0) break;
                data[i] = Entry{ .whole = whole, .type = @enumFromInt(mnemonic.value) };
            } else return .{ data, seed };
        }
        return null;
    }

    fn encodeWholeAndPart(str: []const u8) struct { Whole, Part } {
        std.debug.assert(str.len > 1 and str.len < 8);
        const is_odd = str.len % 2 == 1;
        var whole: Whole = if (is_odd) @intCast(str[0] | 0x20) else 0;
        var i: usize = @as(usize, @intCast(@intFromBool(is_odd)));
        while (i != str.len) : (i += 2) {
            const wchar = @as(u16, str[i]) << 8 | str[i + 1];
            whole = (whole << 16) | (wchar | 0x2020);
        }
        const part: Part = @intCast(((whole >> @intCast(8 * (str.len - 2))) << 16) | (whole & 0xFFFF));
        return .{ whole, part };
    }

    fn hash(input: Part, seed: u32, len: usize) usize {
        return std.hash.Murmur2_32.hashUint32WithSeed(input, seed) % len;
    }

    pub inline fn get(str: []const u8) ?Type {
        if (str.len < 2 or str.len > 7) return null;
        const whole, const part = encodeWholeAndPart(str);
        const token = table.data[hash(part, table.seed, table.data.len)];
        return if (token.whole == whole) token.type else null;
    }
};

type: Type,
location: Location,
data: Data,
pub fn mnemonicStrToType(str: []const u8) ?Type {
    return mnemonics_map.get(str);
}

pub fn List() type {
    const Token = @This();
    return struct {
        const This = @This();
        tokens: std.ArrayList(Token),
        strings: std.ArrayList([]const u8),

        pub fn init(allocator: std.mem.Allocator, text_len: usize) !This {
            const tokens_len: usize = @intFromFloat(@ceil(@as(f64, @floatFromInt(text_len)) * 0.4));
            return This{
                .tokens = try std.ArrayList(Token).initCapacity(allocator, tokens_len),
                .strings = try std.ArrayList([]const u8).initCapacity(allocator, @intFromFloat(@ceil(@as(f64, @floatFromInt(tokens_len)) * 0.15))),
            };
        }

        pub fn deinit(this: This) void {
            this.tokens.deinit();
            this.strings.deinit();
        }

        pub fn items(this: This) []Token {
            return this.tokens.items;
        }

        pub fn addOnlyType(this: *This, t: Type, location: Location) void {
            this.handleTokensCapacity();
            const ptr = this.tokens.addOneAssumeCapacity();
            ptr.type = t;
            ptr.location = location;
        }

        pub fn addWithData(this: *This, t: Token.Type, location: Location, data: Data) void {
            this.handleTokensCapacity();
            this.tokens.addOneAssumeCapacity().* = .{
                .type = t,
                .location = location,
                .data = data,
            };
        }

        inline fn handleTokensCapacity(this: This) void {
            if (this.tokens.capacity == this.tokens.items.len) @panic("TODO FIX ME (Branch predictor wrong)");
        }

        pub fn addWithString(this: *This, t: Token.Type, location: Location, str: []const u8) void {
            this.handleTokensCapacity();
            this.handleStringsCapacity();
            this.tokens.addOneAssumeCapacity().* = .{
                .type = t,
                .location = location,
                .data = .{ .index = @intCast(this.strings.items.len) },
            };
            this.strings.addOneAssumeCapacity().* = str;
        }

        inline fn handleStringsCapacity(this: This) void {
            if (this.strings.capacity == this.strings.items.len) @panic("TODO FIX ME (Branch predictor wrong)");
        }
    };
}
