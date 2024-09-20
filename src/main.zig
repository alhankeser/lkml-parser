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
    name: []u8,
    children: std.StringArrayHashMap(std.ArrayList(Node)),

    pub fn init(allocator: *Allocator) Node {
        return Node{
            .allocator = allocator,
            .name = &[_]u8{},
            .children = std.StringArrayHashMap(std.ArrayList(Node)).init(allocator.*),
        };
    }

    pub fn set_name(self: *Node, name: []u8) void {
        self.name = try std.fmt.allocPrint(self.allocator.*, "{s}", .{name});
    }

    pub fn add_child(self: *Node, child: Node) !void {
        try self.children.put(child);
    }
};


pub const Parser = struct {
    allocator: *Allocator,
    stack: std.ArrayList(*const Token),
    depth: u8,
    json: []u8,
    root: std.StringArrayHashMap(std.ArrayList([]const u8)),
    view: std.StringArrayHashMap(std.ArrayList([]const u8)),
    field: std.StringArrayHashMap(std.ArrayList([]const u8)),
    param: std.StringArrayHashMap(std.ArrayList([]const u8)),
    
    pub fn init(allocator: *Allocator,) !Parser {
        return Parser{
            .allocator = allocator,
            .stack = std.ArrayList(*const Token).init(allocator.*),
            .depth = 0,
            .json = &[_]u8{},
            .root = std.StringArrayHashMap(std.ArrayList([]const u8)).init(allocator.*),
            .view = std.StringArrayHashMap(std.ArrayList([]const u8)).init(allocator.*),
            .field =  std.StringArrayHashMap(std.ArrayList([]const u8)).init(allocator.*),
            .param =  std.StringArrayHashMap(std.ArrayList([]const u8)).init(allocator.*),
        };
    }

    fn stringify_key_value(self: *Parser, key: []u8, value: []u8) ![]u8 {
        return try std.fmt.allocPrint(self.allocator.*, "{s}:{s}", .{key, value});
    }

    fn get_existing_map_arr_or_create(self: *Parser, map:*std.StringArrayHashMap(std.ArrayList([]const u8)), key: []const u8) std.ArrayList([]const u8) {
        const arr_optional = map.get(key);
        if(arr_optional) |arr| {
            return arr;
        } else {
            return std.ArrayList([]const u8).init(self.allocator.*);
        }
    }

    fn add_simple_key_value(self: *Parser, map: *std.StringArrayHashMap(std.ArrayList([]const u8)), key: []const u8, value: []const u8) !void {
        var arr = self.get_existing_map_arr_or_create(map, key);
        try arr.append(value);
        try map.put(key, arr);
    }

    fn create_named_object(self: *Parser, map: *std.StringArrayHashMap(std.ArrayList([]const u8)), key: []const u8, value: []const u8) !void {
        // Create object
        map.clearRetainingCapacity();
        var new_arr = std.ArrayList([]const u8).init(self.allocator.*);
        try new_arr.append(value);
        try map.put("name", new_arr);

        // Add to parent
        const parent = try self.depth_map(self.depth - 1);
        var arr = self.get_existing_map_arr_or_create(map, key);
        try arr.append(value);
        try parent.put(key, arr);
    }

    fn depth_map(self: *Parser, depth: u8) !*std.StringArrayHashMap(std.ArrayList([]const u8)) {
        return switch (depth) {
            0 => &self.root,
            1 => &self.view,
            2 => &self.field,
            3 => &self.param,
            else => &self.root
        };
    }

    fn create_hashmap(self: *Parser) !std.StringArrayHashMap(std.ArrayList([]const u8)) {
        const map = std.StringArrayHashMap(std.ArrayList([]const u8)).init(self.allocator.*);
        return map;
    }

    pub fn parse(self: *Parser, tokenizer: *Tokenizer) ![]u8 {

        var root = try self.create_hashmap();
        // var view: std.StringArrayHashMap(std.ArrayList([]const u8)) = undefined;
        // var field: std.StringArrayHashMap(std.ArrayList([]const u8)) = undefined;
        // var param: std.StringArrayHashMap(std.ArrayList([]const u8)) = undefined;

        while (tokenizer.next()) |token1| {
            
            // var str: []u8 = &[_]u8{};

            var token2_opt: ?Token = null;
            var token2: Token = undefined;

            var token3_opt: ?Token = null;
            var token3: Token = undefined;

            // print("{s}:{any}\n", .{tokenizer.stringify(token1), token1.kind});
            
            if (token1.char == Char.Comment) {
                continue;
            }

            // TOKEN 1
            if (token1.kind == TokenKind.Key) {
                token2_opt = tokenizer.next();
            }

            // TOKEN 2
            if (token2_opt) |t2| {
                token2 = t2;
                token3_opt = tokenizer.peek();
            }
            // TOKEN 3
            if (token3_opt) |t3| {
                token3 = t3;
            }
            
            // Simple key:value
            if (token2.kind == TokenKind.Value and token3.kind == TokenKind.Key) {
                // const map = try self.depth_map(self.depth);
                // var map = &root;
                try self.add_simple_key_value(&root, tokenizer.stringify(token1), tokenizer.stringify(token2));
                continue;
            }

            // Key:value, followed by a control char
            // if (token2.kind == TokenKind.Value and token3.kind == TokenKind.Control) {
            //     _ = switch (token3.char) {
            //         Char.ObjectOpen => {
            //             self.depth += 1;
            //             const map = try self.depth_map(self.depth);
            //             try self.create_named_object(map, tokenizer.stringify(token1), tokenizer.stringify(token2));
            //         }, // create param/field/view, increase depth

            // // //         Char.Comma => //add to param
            // // //         Char.ListClose => //close param, add to field, reduce depth
            // //         // Char.ObjectClose => // close param/field/view, add to parent, reduce depth
            //         else => null
            //     };
            // }

            // if (token2.kind == TokenKind.Control) {
            //     // A key followed by control
            // }
        }
        // try stdout.print("{any}", .{root.children});
        var it = root.iterator();
        while (it.next()) |item| {
            print("{s}:", .{item.key_ptr.*});
            for (item.value_ptr.items) |arr_item| {
                print("{s}\n", .{arr_item});
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
