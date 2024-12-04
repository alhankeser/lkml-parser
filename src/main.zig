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
    name: []const u8,
    children: std.StringArrayHashMap(std.ArrayList(ValueType)),

    pub fn init(allocator: *Allocator, name: []const u8) Node {
        return Node{
            .allocator = allocator,
            .name = name,
            .children = std.StringArrayHashMap(std.ArrayList(ValueType)).init(allocator.*),
        };
    }
};

const ValueType = union(enum) {
    node: Node,
    string: []const u8,
};

pub const Parser = struct {
    allocator: *Allocator,
    stack: std.ArrayList(*const Token),
    depth: u8,
    json: []u8,
    root: Node,
    node_ptr: *Node,
    
    pub fn init(allocator: *Allocator,) !Parser {
        var root = Node.init(allocator, "root");
        return Parser{
            .allocator = allocator,
            .stack = std.ArrayList(*const Token).init(allocator.*),
            .depth = 0,
            .json = &[_]u8{},
            .root = root,
            .node_ptr = &root
        };
    }

    fn stringify_key_value(self: *Parser, key: []u8, value: []u8) ![]u8 {
        return try std.fmt.allocPrint(self.allocator.*, "{s}:{s}", .{key, value});
    }

    fn get_or_create_array(self: *Parser, node:*Node, key: []const u8) std.ArrayList(ValueType) {
        print("{s}\n", .{key});
        const arr_optional = node.children.get(key);
        if (arr_optional) |arr| {
            return arr;
        } else {
            return std.ArrayList(ValueType).init(self.allocator.*);
        }
    }

    fn add_simple_key_value(self: *Parser, node: *Node, key: []const u8, value: ValueType) !void {
        var arr = self.get_or_create_array(node, key);
        try arr.append(value);
        try node.children.put(key, arr);
    }

    fn add_new_object(self: *Parser, parent: *Node, key: []const u8, name: []const u8) !*Node {
       var child = Node.init(self.allocator, name);
       const value = ValueType{.node = child};
       var arr = self.get_or_create_array(parent, key);
       try arr.append(value);
       try parent.children.put(key, arr);
       return &child;
    }

    fn create_hashmap(self: *Parser) !std.StringArrayHashMap(std.ArrayList([]const u8)) {
        const map = std.StringArrayHashMap(std.ArrayList([]const u8)).init(self.allocator.*);
        return map;
    }

    pub fn parse(self: *Parser, tokenizer: *Tokenizer) ![]u8 {
        
        // var node: *Node = &self.root;
        const node: *Node = &self.root;
        while (tokenizer.next()) |token1| {
            var token2_opt: ?Token = null;
            var token2: Token = undefined;
            var token3_opt: ?Token = null;
            var token3: Token = undefined;
            if (token1.char == Char.Comment) { continue; }
            if (token1.kind == TokenKind.Key) { token2_opt = tokenizer.next(); }
            if (token2_opt) |t2| { token2 = t2; token3_opt = tokenizer.peek(); }
            if (token3_opt) |t3| { token3 = t3; }
            
            // Simple key:value
            if (token2.kind == TokenKind.Value and token3.kind == TokenKind.Key) {
                const key = tokenizer.stringify(token1);
                const value = ValueType{.string = tokenizer.stringify(token2)};
                try self.add_simple_key_value(node, key, value);
                continue;
            }

            // Key:value, followed by a control char
            // if (token2.kind == TokenKind.Value and token3.kind == TokenKind.Control) {
            //     _ = switch (token3.char) {
            //         Char.ObjectOpen => {
            //             const key = tokenizer.stringify(token1);
            //             const name = tokenizer.stringify(token2);
            //             node = try self.add_new_object(node, key, name);
            //         },
            //         else => null
            //     };
            // }

            // if (token2.kind == TokenKind.Control) {
            //     // A key followed by control
            // }
        }
        // try stdout.print("{any}", .{root.children});
        var it = self.root.children.iterator();
        while (it.next()) |item| {
            print("{s}:\n", .{item.key_ptr.*});
            for (item.value_ptr.items) |arr_item| {
                print("{s}\n", .{arr_item.string});
            }
        }
        // var it2 = self.view.iterator();
        // while (it2.next()) |item| {
        //     print("{s}:", .{item.key_ptr.*});
        //     for (item.value_ptr.items) |arr_item| {
        //         print("{s}\n", .{arr_item});
        //     }
        // }
        try stdout.print("{s}", .{self.json});
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
