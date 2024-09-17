const std = @import("std");
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const print = std.debug.print;


const Reader = @import("reader.zig").Reader;
const TokenKind = @import("enums.zig").TokenKind;
const ValueKind = @import("enums.zig").ValueKind;
const Token = @import("token.zig").Token;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
// const Parser = @import("parser.zig").Parser;

pub const Parser = struct {
    allocator: *Allocator,
    stack: std.ArrayList(Token),
    json: []u8,
    
    pub fn init(allocator: *Allocator) !Parser {
        return Parser{
            .allocator = allocator,
            .stack = std.ArrayList(Token).init(allocator.*),
            .json = &[_]u8{},
        };
    }

    pub fn parse(self: *Parser, tokenizer: *Tokenizer) ![]u8 {
        for (tokenizer.tokens.items) |token| {
            try self.add(tokenizer.print_token(token));
        }
        try stdout.print("{s}", .{self.json});
        return self.json;
    }

    pub fn add(self: *Parser, chars: []u8) !void {
        const new_json = try std.fmt.allocPrint(self.allocator.*, "{s}{s}", .{self.json,chars});
        self.allocator.free(self.json);
        self.json = new_json;
    }

    pub fn deinit(self: *Parser) void {
        self.allocator.free(self.json);
        self.stack.deinit();
    }
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
    defer tokenizer.deinit();
    try tokenizer.tokenize();
    var parser = try Parser.init(&allocator);
    defer parser.deinit();
    _ = try parser.parse(&tokenizer);

    // for (tokenizer.tokens.items) |token| {
    //     print("{s}\n", .{tokenizer.print_token(token)});
    // }

    // defer allocator.free(reader);
    // return lkml;
}
