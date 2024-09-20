const std = @import("std");
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const print = std.debug.print;

const Reader = @import("reader.zig").Reader;
const Token = @import("token.zig").Token;
const State = @import("enums.zig").State;
const Char = @import("enums.zig").Char;
const TokenKind = @import("enums.zig").TokenKind;
const ValueKind = @import("enums.zig").ValueKind;

pub const Tokenizer = struct {
    allocator: *Allocator,
    reader: Reader,
    state: State,
    curr_char: Char,
    prev_char: Char,
    previous_state: State,
    tokens: std.ArrayList(Token),
    token_idx: i32,

    pub fn init(allocator: *Allocator, reader: Reader) !Tokenizer {
        return Tokenizer{
            .allocator =  allocator,
            .reader = reader,
            .state = State.SeekKey,
            .curr_char = Char.SOF,
            .prev_char = Char.SOF,
            .previous_state = State.NotStarted,
            .tokens = std.ArrayList(Token).init(allocator.*),
            .token_idx = -1,
        };
    }

    fn init_curr_char(self: *Tokenizer) Char {
        self.curr_char = self.char_type(self.reader.curr());
        return self.curr_char;
    }

    fn char_type(self: *Tokenizer, c: u8) Char {
        _ = self;
        const char = switch(c) {
            ':' => Char.Colon,
            ';' => Char.SemiColon,
            '[' => Char.ListOpen,
            ']' => Char.ListClose,
            ',' => Char.Comma,
            '{' => Char.ObjectOpen,
            '}' => Char.ObjectClose,
            '"' => Char.Quote,
            ' ' => Char.Space,
            '\n' => Char.NewLine,
            '#' => Char.Comment,
            0 => Char.EOF,
            else => Char.NotSpecial,
        };
        // print("{any}\n", .{char});
        return char;
    }

    pub fn tokenize(self: *Tokenizer) !void {
        var c = self.init_curr_char();
        while(!self.reader.finished()) {
            const i = self.reader.i;
            const t = self.handle_char(c);
            if (t) |token| {
                try self.tokens.append(token);
            }
            if (i == self.reader.i) {
                c = try self.next_char();
            } else {
                c = self.curr_char;
            }
        }
        // for (self.tokens.items) |token| {
        //     // try stdout.print("{any}:", .{token.kind});
        //     // try stdout.print("{any}:", .{token.range});
        //     // try stdout.print("{s}\n", .{self.stringify(token)});
        //     try stdout.print("{any}\n", .{token});
        // }
    }


    fn handle_char(self: *Tokenizer, c: Char) ?Token {
        // print("{any} + ", .{c});
        // print("{any}\n", .{self.state});
        if (self.state == State.ReadSqlValue and c != Char.Colon) {
            return self.handle_state();
        }
        if (self.state == State.SeekValue and c == Char.Quote) {
            self.set_state(State.ReadQuotedValue);
            return self.handle_state();
        }
        if (self.state != State.ReadQuotedValue and (c == Char.Space or c == Char.NewLine)) {
            return self.skip_space();
        }
        if (c == Char.Comment) {
            self.set_state(State.ReadComment);
            return self.handle_state();
        }
        if (self.state == State.SeekKey and c == Char.NotSpecial) {
            self.set_state(State.ReadKey);
            return self.handle_state();
        }
        if (self.state == State.SeekValue and c == Char.NotSpecial) {
            self.set_state(State.ReadUnquotedValue);
            return self.handle_state();
        }
        if (c == Char.Comma
            or c == Char.ListOpen
            or c == Char.ListClose
            or c == Char.ObjectOpen
            or c == Char.ObjectClose) {
            self.set_state(State.ReadControlChar);
            return self.handle_state();
        }
        return null;
    }

    fn set_state(self: *Tokenizer, state: State) void {
        if (self.state != state) {
            self.previous_state = self.state;
        }
        self.state = state;
    }

    fn handle_state(self: *Tokenizer) ?Token {
        const t: ?Token = switch (self.state) {
            .SeekKey => {
                return null;
            },
            .ReadKey => {
                return self.read_key();
            },
            .SeekValue => {
                return null;
            },
            .ReadSqlValue => {
                return self.read_sql_value();
            },
            .ReadControlChar => {
                return self.read_control_char();
            },
            .ReadUnquotedValue => {
                return self.read_unquoted_value();
            },
            .ReadQuotedValue => {
                return self.read_quoted_value();
            },
            .Done => {
                return null;
            },
            .ReadComment => {
                return self.read_comment();
            },
            .NotStarted => {
                return null;
            },
        };
        return t;
    }

    fn next_char(self: *Tokenizer) !Char {
        const char = self.char_type(self.reader.next());
        self.prev_char = self.curr_char;
        self.curr_char = char;
        return char;
    }

    fn read_key(self: *Tokenizer) Token {
        self.reader.reset_range();
        var c = self.curr_char;
        while (c == Char.NotSpecial and c != Char.Colon and !self.reader.finished()) {
            c = try self.next_char();
        }
        var t = Token.init(TokenKind.Key, ValueKind.UnQuoted, Char.NotSpecial, self.reader.line);
        t.set_range(self.reader.range());
        const printed = self.stringify(t);
        if (std.mem.eql(u8, "sql", printed)
            or (printed.len >= 4 and std.mem.eql(u8, "sql_", printed[0..4]))
            ) {
            self.set_state(State.ReadSqlValue);
        } else {
            self.set_state(State.SeekValue);
        }
        return t;
    }

    fn read_unquoted_value(self: *Tokenizer) Token {
        self.reader.reset_range();
        var c = self.curr_char;
        while (c == Char.NotSpecial and c != Char.Space and !self.reader.finished()) {
            c = try self.next_char();
        }
        var t = Token.init(TokenKind.Value, ValueKind.UnQuoted, Char.NotSpecial, self.reader.line);
        t.set_range(self.reader.range());
        self.set_state(State.SeekKey);
        return t;
    }

    fn read_quoted_value(self: *Tokenizer) Token {
        var c = try self.next_char();
        self.reader.reset_range();
        while (c != Char.Quote and c != Char.Comment and !self.reader.finished()) {
            c = try self.next_char();
        }
        var t = Token.init(TokenKind.Value, ValueKind.Quoted, Char.NotSpecial, self.reader.line);
        t.set_range(self.reader.range());
        self.set_state(State.SeekKey);
        return t;
    }

    fn read_sql_value(self: *Tokenizer) Token {
        _ = self.skip_space();
        self.reader.reset_range();
        var c = self.curr_char;
        while (!(c == Char.SemiColon and self.prev_char == Char.SemiColon)
                and c != Char.Comment and !self.reader.finished()) {
            c = try self.next_char();
        }
        var t = Token.init(TokenKind.Value, ValueKind.Sql, Char.NotSpecial, self.reader.line);
        t.set_range(self.reader.range());
        if (t.range[1]-t.range[0] > 1) {
            t.range[1] -= 1;
        }
        t = self.trim_space(t);
        self.set_state(State.SeekKey);
        return t;
    }

    fn read_control_char(self: *Tokenizer) Token {
        self.reader.reset_range();
        var t = Token.init(TokenKind.Control, ValueKind.UnQuoted, self.curr_char, self.reader.line);
        t.set_range(self.reader.range());
        self.set_state(State.SeekKey);
        return t;
    }

    fn skip_space(self: *Tokenizer) ?Token {
        var c = self.curr_char;
        while (!self.reader.finished() and (c == Char.Space or c == Char.NewLine)) {
            c = try self.next_char();
        }
        return null;
    }

    fn trim_space(self: *Tokenizer, token: Token) Token {
        const content = self.stringify(token);
        const trimmed = std.mem.trim(u8, content, "\n ");
        var t = token;
        t.set_range(.{token.range[0], @intCast(token.range[0]+trimmed.len)});
        return t;
    }

    pub fn read_comment(self: *Tokenizer) Token {
        self.reader.reset_range();
        var c = self.curr_char;
        while (!self.reader.finished() and c != Char.NewLine) {
            c = try self.next_char();
        }
        var t = Token.init(TokenKind.Value, ValueKind.UnQuoted, Char.Comment, self.reader.line);
        t.set_range(self.reader.range());
        self.set_state(State.SeekKey);
        return t;
    }

    fn token_index(self: *Tokenizer) u32 {
        const i: u32 = @intCast(self.token_idx);
        return i;
    }

    pub fn next(self: *Tokenizer) ?Token {
        self.token_idx += 1;
        if (self.token_idx < self.tokens.items.len) {
            const i = self.token_index();
            return self.tokens.items[i];
        }
        return null;
    }

    pub fn peek(self: *Tokenizer) ?Token {
        const i = self.token_index();
        if (i + 1 < self.tokens.items.len) {
            return self.tokens.items[i + 1];
        }
        return null;
    }

    pub fn previous(self: *Tokenizer) ?Token {
        const i = self.token_index();
        if (i - 1 >= 0) {
            return self.tokens.items[i - 1];
        }
        return null;
    }

    pub fn stringify(self: *Tokenizer, token: Token) []u8 {
        return self.reader.lkml[token.range[0]..token.range[1]];
    }

    pub fn deinit(self: *Tokenizer) void {
        self.tokens.deinit();
    }
};
