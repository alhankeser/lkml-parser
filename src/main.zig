const std = @import("std");
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const print = std.debug.print;


pub const Reader = struct {
    lkml: []u8,
    i: u32,
    line: u32,
    start: u32,

    pub fn init(lkml: []u8) Reader {
        return Reader{
            .lkml = lkml,
            .i = 0,
            .line = 1,
            .start = 0,
        };
    }

    pub fn next(self: *Reader) u8 {
        if (!self.finished()) {
            self.i += 1;
            return self.curr();
        }
        return 0;
    }

    pub fn finished(self: *Reader) bool {
        return (self.i + 1) >= self.lkml.len;
    }

    pub fn curr(self: *Reader) u8 {
        const result = self.lkml[self.i];
        if (result == 10) {
            self.new_line();
        }
        return result;
    }

    fn curr_line(self: *Reader) u32 {
        return self.line;
    }

    fn new_line(self: *Reader) void {
        self.line += 1;
    }

    pub fn reset_range(self: *Reader) void {
        self.start = self.i;
    }

    pub fn range(self: *Reader) [2]u32 {
        return [2]u32{self.start, self.i};
    }

    pub fn chars(self: *Reader) []u8 {
        if (self.start <= self.i) {
            return self.lkml[self.start..self.i];
        }
        return &[_]u8{};
    }
};

pub const ValueKind = enum {
    UnQuoted,
    Quoted,
    Sql,
};

pub const TokenKind = enum {
    Key,
    Value,
    Control,
};

pub const Token = struct {
    kind: TokenKind,
    char: Char,
    range: [2]u32,

    pub fn init(kind: TokenKind, char: Char) Token {
        return Token{
            .kind = kind,
            .char = char,
            .range = [2]u32{0,0},
        };
    }

    pub fn set_range(self: *Token, range: [2]u32) void {
        self.range = range;
    }
};

pub const Char = enum {
    Colon,
    SemiColon,
    ListOpen,
    ListClose,
    Comma,
    ObjectOpen,
    ObjectClose,
    Quote,
    Space,
    NewLine,
    Comment,
    NotSpecial,
    EOF,
};


pub const Tokenizer = struct {
    allocator: *Allocator,
    reader: Reader,
    state: State,
    previous_state: State,
    tokens: std.ArrayList(Token),

    pub fn init(allocator: *Allocator, reader: Reader) !Tokenizer {
        return Tokenizer{
            .allocator =  allocator,
            .reader = reader,
            .state = State.SeekKey,
            .previous_state = State.NotStarted,
            .tokens = std.ArrayList(Token).init(allocator.*),
        };
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
        var c = try self.curr_char();
        while(!self.reader.finished()) {
            const i = self.reader.i;
            const t = self.handle_char(c);
            if (t) |token| {
                try self.tokens.append(token);
            }
            if (i == self.reader.i) {
                c = try self.next_char();
            } else {
                c = try self.curr_char();
            }
        }
        for (self.tokens.items) |token| {
            print("{any}\n", .{token});
            print("{s}\n", .{self.reader.lkml[token.range[0]..token.range[1]]});
        }
    }


    fn handle_char(self: *Tokenizer, c: Char) ?Token {
        print("{any}\n", .{c});
        if (self.state != State.ReadValue and (c == Char.Space or c == Char.NewLine)) {
            print("Skip Space block\n", .{});
            self.set_state(State.SkipSpace);
            return self.handle_state();
        }
        if (self.state != State.ReadComment and c == Char.Comment) {
            print("Read Comment block\n", .{});
            self.set_state(State.ReadComment);
            return self.handle_state();
        }
        return null;
    }

    fn set_state(self: *Tokenizer, state: State) void {
        if (self.state != state) {
            self.previous_state = self.state;
        }
        self.state = state;
        print("{any}\n", .{self.state});
    }

    fn handle_state(self: *Tokenizer) ?Token {
        const t: ?Token = switch (self.state) {
            .SeekKey => {
                print("SeekKey\n", .{});
                return self.seek_key();
            },
            .ReadKey => {
                print("ReadKey\n", .{});
                return self.read_key();
            },
            .SeekValue => {
                print("SeekValue\n", .{});
                return null;
            },
            .ReadValue => {
                print("ReadValue\n", .{});
                return null;
            },
            .Done => {
                print("Done\n", .{});
                return null;
            },
            .ReadComment => {
                print("ReadComment\n", .{});
                return self.read_comment();
            },
            .NotStarted => {
                print("NotStarted\n", .{});
                return null;
            },
            .SkipSpace => {
                print("SkipSpace\n", .{});
                self.skip_space();
                return null;
            },
        };
        return t;
    }

    fn curr_char(self: *Tokenizer) !Char {
        return self.char_type(self.reader.curr());
    }

    fn next_char(self: *Tokenizer) !Char {
        return self.char_type(self.reader.next());
    }

    fn seek_key(self: *Tokenizer) ?Token {
        const c = try self.curr_char();
        if (c == Char.NotSpecial) {
            self.set_state(State.ReadKey);
        }
        return null;
    }

    fn read_key(self: *Tokenizer) Token {
        self.reader.reset_range();
        var c = try self.curr_char();
        while (c == Char.NotSpecial and c != Char.Colon) {
            c = try self.next_char();
        }
        var t = Token.init(TokenKind.Value, Char.Comment);
        t.set_range(self.reader.range());
        self.set_state(State.ReadValue);
        return t;
    }

    fn skip_space(self: *Tokenizer) void {
        var c = try self.curr_char();
        while (!self.reader.finished() and (c == Char.Space or c == Char.NewLine)) {
            c = try self.next_char();
        }
        // self.set_state(self.previous_state);
    }

    pub fn read_comment(self: *Tokenizer) Token {
        self.reader.reset_range();
        var c = try self.curr_char();
        while (!self.reader.finished() and c != Char.NewLine) {
            c = try self.next_char();
        }
        var t = Token.init(TokenKind.Value, Char.Comment);
        t.set_range(self.reader.range());
        self.set_state(self.previous_state);
        return t;
    }

    pub fn deinit(self: *Tokenizer) void {
        self.tokens.deinit();
    }
};


pub const State = enum {
    Done,
    SeekKey,
    ReadKey,
    SeekValue,
    ReadValue,
    ReadComment,
    NotStarted,
    SkipSpace,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();
    // var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena_allocator.deinit();
    // var allocator = arena_allocator.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const filePath = args[1];
    const file = try std.fs.cwd().openFile(filePath, .{});
    const fileSize = (try file.stat()).size;
    defer file.close();
    const lkml = try file.readToEndAlloc(allocator, fileSize);
    defer allocator.free(lkml);

    const reader = Reader.init(lkml);
    var tokenizer = try Tokenizer.init(&allocator, reader);
    try tokenizer.tokenize();
    defer tokenizer.deinit();
    // defer allocator.free(reader);
    // return lkml;
}
