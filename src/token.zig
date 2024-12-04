const TokenKind = @import("enums.zig").TokenKind;
const ValueKind = @import("enums.zig").ValueKind;
const Char = @import("enums.zig").Char;

pub const Token = struct {
    kind: TokenKind,
    value_kind: ValueKind,
    char: Char,
    range: [2]u32,
    line: u32,

    pub fn init(kind: TokenKind, value_kind: ValueKind, char: Char, line: u32) Token {
        return Token{ .kind = kind, .value_kind = value_kind, .char = char, .range = [2]u32{ 0, 0 }, .line = line };
    }

    pub fn set_range(self: *Token, range: [2]u32) void {
        self.range = range;
    }
};
