const std = @import("std");
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const print = std.debug.print;


const Reader = @import("reader.zig").Reader;
const TokenKind = @import("enums.zig").TokenKind;
const ValueKind = @import("enums.zig").ValueKind;
const Char = @import("enums.zig").Char;
const Token = @import("token.zig").Token;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
// const Parser = @import("parser.zig").Parser;

pub const Node = struct {
    allocator: *Allocator,
    depth: usize,
    key: ?*Token,
    value: ?*Token,
    children: std.ArrayList(*Node),

    pub fn init(allocator: *Allocator, depth: usize, key: ?*Token, value: ?*Token) Node {
        return Node{
            .allocator = allocator,
            .depth = depth,
            .key = key,
            .value = value,
            .children = std.ArrayList(*Node).init(allocator.*),
        };
    }

    pub fn addChild(self: *Node, node: *Node) !void {
        try self.children.append(node);
    }

    pub fn create(self: *Node, depth: usize, key: ?*Token, value: ?*Token) Node {
        const node = Node.init(self.allocator, depth, key, value);
        return node;
    }

    pub fn deinit(self: *Node,) void {
        for (self.children.items) |child_node| {
            child_node.deinit();
            self.allocator.destroy(child_node);
        }
        self.children.deinit();
    }
};

pub const Parser = struct {
    allocator: *Allocator,
    stack: std.ArrayList(*const Token),
    node: *Node,
    json: []u8,
    
    pub fn init(allocator: *Allocator,) !Parser {
        var node = Node.init(allocator, 0, null, null);
        return Parser{
            .allocator = allocator,
            .stack = std.ArrayList(*const Token).init(allocator.*),
            .json = &[_]u8{},
            .node = &node,
        };
    }
 
    pub fn parse(self: *Parser, tokenizer: *Tokenizer) ![]u8 {
        var key: Token = undefined;
        var value: Token = undefined;
        while (tokenizer.next()) |token| {
            // print("{any}", .{token});

            if (token.kind == TokenKind.Key) {
                key = token;
            }

            if (token.kind == TokenKind.Value) {
                value = token;
            }
            
            // Open List/Object
            if (token.kind == TokenKind.Control
                and (token.char == Char.ListOpen or token.char == Char.ObjectOpen)) {
                // print("{any}", .{token});
                // var node = Node.init(self.allocator, self.stack.items.len, &key, &value);
                if (@TypeOf(key) == Token) {
                    print("{any}\n", .{key});
                    var node = self.node.create(self.stack.items.len, &key, &value);
                    try self.node.addChild(&node);
                    key = undefined;
                    value = undefined;
                }
                if (tokenizer.previous()) |previous_token| {
                    try self.stack.append(&previous_token);
                }
            }

            // Close List/Object
            // if (token.kind == TokenKind.Control
            //     and (token.char == Char.ListClose or token.char == Char.ObjectClose)) {
            //     // print("{any}", .{token});
            //     _ = self.stack.pop();
            // }

            // for (self.node.children.items) |node| {
            //     print("{any}\n", .{node.*.key});
            // }

            // try self.appendToJson(tokenizer.print_token(token));
        }
        try stdout.print("stack_count:{any}\n", .{self.stack.items.len});
        for (self.stack.items) |token| {
            try stdout.print("{s}\n", .{tokenizer.print_token(token.*)});
        }
        return self.json;
    }

    pub fn appendToJson(self: *Parser, chars: []u8) !void {
        const new_json = try std.fmt.allocPrint(self.allocator.*, "{s}{s}", .{self.json,chars});
        self.allocator.free(self.json);
        self.json = new_json;
    }

    pub fn deinit(self: *Parser) void {
        self.allocator.free(self.json);
        self.stack.deinit();
        // self.node.deinit();
    }
};

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    // var allocator = gpa.allocator();
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    var allocator = arena_allocator.allocator();
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
}
