const std = @import("std");
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const print = std.debug.print;


const Reader = @import("reader.zig").Reader;
const TokenKind = @import("enums.zig").TokenKind;
const ValueKind = @import("enums.zig").ValueKind;
const Token = @import("token.zig").Token;
const Tokenizer = @import("tokenizer.zig").Tokenizer;


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
