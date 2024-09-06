const std = @import("std");
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const print = std.debug.print;

var objects = [_][]const u8{"view", "derived_table", "action", "derived_table", "filter", "parameter", "dimension", "dimension_group", "measure", "set"};
var fields = [_][]const u8{"derived_table", "filter", "parameter", "dimension", "dimension_group", "measure", "set"};

pub fn isInList(needle: []const u8, haystack: [][]const u8) bool {
    for (haystack) |thing| {
        if (eq(needle, thing)) {
            return true;
        }
    }
    return false;
}

pub fn eq(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub fn trimString(chars: []u8) []const u8 {
    return std.mem.trim(u8, chars, "\n ");
}

pub fn keyContainsSql(key: []const u8) bool {
    const index = std.mem.indexOf(u8, key, "sql");
    if (index) |idx| {
        _ = idx;
        return true;
    }
    return false;
}


pub const Parser = struct {
    allocator: Allocator,
    stack: std.ArrayList([]const u8),
    chars: []u8,
    totalChars: u32,
    depth: i8,
    isComment: bool,
    isQuoted: bool,
    isNonQuoted: bool,
    isBrackets: bool,
    isVariable: bool,
    isValue: bool,
    isSql: bool,
    lastKey: []const u8,
    valueTerminatorChar: u8,
    output: []u8,
    key: []u8,
    currentFieldChars: []u8,
    currentViewChars: []u8,
    includes: std.ArrayList([]const u8),
    views: std.ArrayList([]const u8),
    fields: std.ArrayList([]const u8),

    pub fn init(allocator: Allocator) !Parser {
        return .{
            .allocator = allocator,
            .stack = std.ArrayList([]const u8).init(allocator),
            .chars = &[_]u8{},
            .totalChars = 0,
            .depth = 0,
            .isComment = false,
            .isQuoted = false,
            .isNonQuoted = false,
            .isBrackets = false,
            .isVariable = false,
            .isValue = false,
            .isSql = false,
            .lastKey = &[_]u8{},
            .valueTerminatorChar = 0,
            .output = &[_]u8{},
            .key = &[_]u8{},
            .currentFieldChars = &[_]u8{},
            .currentViewChars = &[_]u8{},
            .includes = std.ArrayList([]const u8).init(allocator),
            .views = std.ArrayList([]const u8).init(allocator),
            .fields = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn addChar(self: *Parser, char: u8) !void {
        const sizeNeeded = self.chars.len + 1;
        const buffer = try self.allocator.alloc(u8, sizeNeeded);
        std.mem.copyForwards(u8, buffer[0..self.chars.len], self.chars);
        buffer[self.chars.len] = char;
        self.allocator.free(self.chars);
        self.chars = buffer[0..sizeNeeded];
        self.totalChars += 1;
    }

    pub fn getOutput(self: *Parser) ![]const u8 {
        try self.addOutput("{", 0);
        if (self.includes.items.len > 0) {
            try self.addOutput("\"includes\": [", 0);
            for (self.includes.items) |item| {
                try self.addOutput(try std.fmt.allocPrint(self.allocator, "{s},", .{item}), 0);
            }
            self.output = self.output[0..self.output.len-1];
            try self.addOutput("],", 0);
        }
        if (self.views.items.len > 0) {
            try self.addOutput("\"views\": [", 0);
            for (self.views.items) |item| {
                try self.addOutput(try std.fmt.allocPrint(self.allocator, "{{{s}}},", .{item}), 0);
            }
            self.output = self.output[0..self.output.len-1];
            try self.addOutput("],", 0);
        }
        self.output = self.output[0..self.output.len-1];
        try self.addOutput("}", 0);
        return self.output;
    }

    pub fn addOutput(self: *Parser, chars: []const u8, offset: usize) !void {
        const totalSize = self.output.len + chars.len;
        const buffer = try self.allocator.alloc(u8, totalSize);
        var safeOffset = offset;
        if (safeOffset > self.output.len) {
            safeOffset = self.output.len;
        }
        const outputPreEndIndex = self.output.len - safeOffset;
        const charsEndIndex = outputPreEndIndex + chars.len;
        const outputPre = self.output[0..outputPreEndIndex];
        const outputPost = self.output[outputPreEndIndex..];
        std.mem.copyForwards(u8, buffer[0..outputPreEndIndex], outputPre);
        std.mem.copyForwards(u8, buffer[charsEndIndex..], outputPost);
        std.mem.copyForwards(u8, buffer[outputPreEndIndex..charsEndIndex], chars);
        self.allocator.free(self.output);
        self.output = buffer;
    }

    pub fn removeOutputLastChars(self: *Parser, charCount: u16) void {
        if (self.output.len > charCount) {
            const newLen = self.output.len - charCount;
            self.output = self.output[0..newLen];
        }
    }

    pub fn printDeezChars(self: *Parser) !void {
        print("{s}\n", .{self.chars});
    }

    pub fn parse(self: *Parser, char: u8) !void {
        var previous_char = char;
        if (self.chars.len > 0) {
            previous_char = self.chars[self.chars.len-1];
        }
        if (self.isComment and char == 10) {
            self.isComment = false;
        }
        if (self.isComment) {
            return;
        }
        // escape backslashes
        if (char == 92) {
            try self.addChar(92);
        }
        // backslash any quotes in content
        if (char == 34 and previous_char != 92) {
            try self.addChar(92);
        }
        // // escape return
        if (self.isValue and !self.isNonQuoted and char == 10) {
            try self.addChar(92);
            try self.addChar(110);
        } else {
            try self.addChar(char);
        }
        
        if (char == 35) {
            self.isComment = true;
            self.chars = self.chars[0..self.chars.len-1];
        }
        // value close
        if (self.isValue and previous_char != 92 and (
            (!self.isSql and self.valueTerminatorChar == char)
            or (self.chars.len > 1
                and self.isSql
                and self.valueTerminatorChar == char
                and self.chars[self.chars.len - 2] == self.valueTerminatorChar)
            or (self.chars.len > 1
                and self.isNonQuoted
                and (self.valueTerminatorChar == char or char == 10)))) {
            
            // remove terminal char from sql
            if (self.isSql) {
                self.chars = self.chars[0..self.chars.len-2];
                while(self.chars[self.chars.len-1] == 32) {
                    self.chars = self.chars[0..self.chars.len-1];
                }
                if (self.chars[self.chars.len-1] == 110 and self.chars[self.chars.len - 2] == 92) {
                    self.chars = self.chars[0..self.chars.len-2];
                }
            }

            // maybe pop stack
            if (!isInList(self.lastKey, &objects) and self.stack.items.len > self.depth) {
                const last_closed_key = self.stack.pop();
                
                var parent_key: []const u8 = "";
                var is_captured = false;
                if (self.stack.items.len > 0) {
                    parent_key = self.stack.getLast();
                }
                
                if (eq(last_closed_key, "include")) {
                    try self.includes.append(try std.fmt.allocPrint(self.allocator, "\"{s}\"",.{trimString(self.chars)}));
                    is_captured = true;
                }
                if (!is_captured and eq(parent_key, "view")){
                    self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}\"{s}\":\"{s}\",", .{self.currentViewChars, last_closed_key, trimString(self.chars)});
                    is_captured = true;
                }
                if (!is_captured and isInList(parent_key, &fields)){
                    self.currentFieldChars = try std.fmt.allocPrint(self.allocator, "{s}\"{s}\":\"{s}\",", .{self.currentFieldChars, last_closed_key, trimString(self.chars)});
                    is_captured = true;
                }
            } else if (self.isValue) {
                var parent_key: []const u8 = "";
                var is_captured = false;
                if (self.stack.items.len > 0) {
                    parent_key = self.stack.getLast();
                }
                if (eq(parent_key, "view")) {
                    self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}\"name\":\"{s}\",", .{self.currentViewChars, trimString(self.chars)});
                    is_captured = true;
                }
                if (!is_captured and isInList(parent_key, &fields)) {
                    self.currentFieldChars = try std.fmt.allocPrint(self.allocator, "{s}\"name\":\"{s}\",", .{self.currentFieldChars, trimString(self.chars)});
                }
            }

            // brackets close
            if (self.isBrackets) {
                self.isBrackets = false;
            }
            // sql close
            if (self.isSql) {
                self.isSql = false;
            }
            // quotes close
            if (self.isQuoted) {
                self.isQuoted = false;
            }
            // non quoted close
            if (self.isNonQuoted) {
                self.isNonQuoted = false;
            }
            
            // reset the rest
            self.lastKey = &[_]u8{};
            self.isValue = false;
            self.valueTerminatorChar = 0;
            self.chars = &[_]u8{};
            return;
        }
        if (!self.isQuoted and !self.isBrackets and !self.isNonQuoted and !self.isSql) {
            // curly braces open
            if (char == 123) {
                self.depth += 1;
                if (self.chars.len > 1 and self.chars[self.chars.len - 2] == 36) {
                    self.isVariable = true;
                }
                self.chars = &[_]u8{};
                self.isValue = false;
                return;
            }

            // curly braces close
            if (char == 125) {
                self.depth -= 1;
                if (self.isVariable) {
                    self.isVariable = false;
                }
                const last_closed_key = self.stack.pop();
                var is_captured = false;
                if (eq(last_closed_key, "view")) {
                    var dimensions = std.ArrayList([]const u8).init(self.allocator);
                    var dimension_groups = std.ArrayList([]const u8).init(self.allocator);
                    var measures = std.ArrayList([]const u8).init(self.allocator);
                    var filters = std.ArrayList([]const u8).init(self.allocator);
                    var parameters = std.ArrayList([]const u8).init(self.allocator);
                    var derived_table: []u8 = &[_]u8{};
                    for (self.fields.items) |item| {
                        var field_type_split = std.mem.splitSequence(u8, item, "<###>");
                        if (field_type_split.next()) |field_type| {
                            if (field_type_split.next()) |field_chars| {
                                if (eq(field_type, "dimension")) {
                                    try dimensions.append(field_chars);
                                }
                                if (eq(field_type, "dimension_group")) {
                                    try dimension_groups.append(field_chars);
                                }
                                if (eq(field_type, "measure")) {
                                    try measures.append(field_chars);
                                }
                                if (eq(field_type, "filter")) {
                                    try filters.append(field_chars);
                                }
                                if (eq(field_type, "parameter")) {
                                    try parameters.append(field_chars);
                                }
                                if (eq(field_type, "derived_table")) {
                                    derived_table = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{derived_table, field_chars});
                                }
                            }
                        }
                    }
                    
                    if (dimensions.items.len > 0) {
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}\"dimensions\": [", .{self.currentViewChars});
                        for (dimensions.items) |item| {
                            self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}{{{s}}},", .{self.currentViewChars, item});
                        }
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}],", .{self.currentViewChars[0..self.currentViewChars.len-1]});
                    }
                    if (dimension_groups.items.len > 0) {
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}\"dimension_groups\": [", .{self.currentViewChars});
                        for (dimension_groups.items) |item| {
                            self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}{{{s}}},", .{self.currentViewChars, item});
                        }
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}],", .{self.currentViewChars[0..self.currentViewChars.len-1]});
                    }
                    if (measures.items.len > 0) {
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}\"measures\": [", .{self.currentViewChars});
                        for (measures.items) |item| {
                            self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}{{{s}}},", .{self.currentViewChars, item});
                        }
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}],", .{self.currentViewChars[0..self.currentViewChars.len-1]});
                    }
                    if (filters.items.len > 0) {
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}\"filters\": [", .{self.currentViewChars});
                        for (filters.items) |item| {
                            self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}{{{s}}},", .{self.currentViewChars, item});
                        }
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}],", .{self.currentViewChars[0..self.currentViewChars.len-1]});
                    }
                    if (parameters.items.len > 0) {
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}\"parameters\": [", .{self.currentViewChars});
                        for (parameters.items) |item| {
                            self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}{{{s}}},", .{self.currentViewChars, item});
                        }
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}],", .{self.currentViewChars[0..self.currentViewChars.len-1]});
                    }
                    if (derived_table.len > 0) {
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}\"derived_table\": ", .{self.currentViewChars});
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}{{{s}}},", .{self.currentViewChars, derived_table});
                    }
                    if (self.currentViewChars.len > 0) {
                        self.currentViewChars = self.currentViewChars[0..self.currentViewChars.len-1];
                    }
                    try self.views.append(self.currentViewChars);
                    self.currentViewChars = &[_]u8{};
                    self.fields.clearAndFree();
                    is_captured = true;
                }
                if (!is_captured and isInList(last_closed_key, &fields)) {
                    self.currentFieldChars = try std.fmt.allocPrint(self.allocator, "{s}<###>{s}", .{last_closed_key, self.currentFieldChars, });
                    try self.fields.append(self.currentFieldChars[0..self.currentFieldChars.len-1]);
                    self.currentFieldChars = &[_]u8{};
                    is_captured = true;
                }
                self.chars = &[_]u8{};
                return;
            }

            // key
            if (!self.isValue and char == 58 and (self.chars[0] == 32 or self.chars[0] == 10 or self.chars.len == self.totalChars)) {
                var key = trimString(self.chars[0..]);
                key = key[0..key.len-1];
                try self.stack.append(key);
                self.lastKey = key;
                self.isValue = true;
                self.chars = &[_]u8{};
                return;
            }

            // brackets open
            if (char == 91) {
                self.isBrackets = true;
                self.valueTerminatorChar = 93;
                self.chars = &[_]u8{};
                return;
            }

            // quotes open
            if (char == 34 or char == 39) {
                self.valueTerminatorChar = char;
                self.isQuoted = true;
                return;
            }

            // first char of value is not quote or bracket
            if (self.isValue and char != 32) {
                self.isSql = keyContainsSql(self.lastKey);
                if (self.isSql) {
                    self.valueTerminatorChar = 59;
                } else {
                    self.isNonQuoted = true;
                    self.valueTerminatorChar = 32;
                }
                return;
            }
        }
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const filePath = args[1];
    const file = try std.fs.cwd().openFile(filePath, .{});
    const fileSize = (try file.stat()).size;
    defer file.close();
    const readBuf = try file.readToEndAlloc(allocator, fileSize);
    defer allocator.free(readBuf);

    // Parse
    var parser = try Parser.init(allocator);
    var chars = std.mem.window(u8, readBuf, 1, 1);
    while (chars.next()) |char| {
        try parser.parse(char[0]);
    }

    // Print out
    const output = try parser.getOutput();
    _ = try stdout.write(output);
}
