const std = @import("std");
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const print = std.debug.print;

var lkmlParams = [_][]const u8{ "view:", "explore:", "include:", "extends:" };
var viewParams = [_][]const u8{ "label:", "extension:", "sql_table_name:", "drill_fields:", "suggestions:", "fields_hidden_by_default:", "extends:", "required_access_grants:", "derived_table:", "filter:", "parameter:", "dimension:", "dimension_group:", "measure:", "set:" };
var paramNames = [_][]const u8{ "action:", "alias:", "allow_approximate_optimization:", "allow_fill:", "allowed_value:", "alpha_sort:", "approximate:", "approximate_threshold:", "bypass_suggest_restrictions:", "can_filter:", "case:", "case_sensitive:", "convert_tz:", "datatype:", "default_value:", "description:", "direction:", "drill_fields:", "end_location_field:", "fanout_on:", "fields:", "filters:", "full_suggestions:", "group_item_label:", "group_label:", "hidden:", "html:", "intervals:", "label:", "label_from_parameter:", "link:", "list_field:", "map_layer_name:", "order_by_field:", "percentile:", "precision:", "primary_key:", "required_access_grants:", "required_fields:", "skip_drill_filter:", "sql:", "sql_distinct_key:", "sql_end:", "sql_latitude:", "sql_longitude:", "sql_start:", "start_location_field:", "string_datatype:", "style:", "suggest_dimension:", "suggest_explore:", "suggest_persist_for:", "suggestable:", "suggestions:", "tags:", "tiers:", "timeframes:", "type:", "units:", "value_format:", "value_format_name:", "view_label:" };

var objects = [_][]const u8{"view", "derived_table", "action", "derived_table", "filter", "parameter", "dimension", "dimension_group", "measure", "set"};
var fields = [_][]const u8{"filter", "parameter", "dimension", "dimension_group", "measure", "set"};

pub fn isInList(needle: []const u8, haystack: [][]const u8) bool {
    for (haystack) |thing| {
        if (eq(needle, thing)) {
            return true;
        }
    }
    return false;
}

pub fn printStrings(items: [][]const u8) !void {
    const count = items.len;
    var i: i8 = 1;
    print("[", .{});
    for (items) |item| {
        print("\"{s}\"", .{item});
        if (i < count) {
            try printComma();
        }
        i += 1;
    }
    print("]", .{});
}

pub fn printObjects(T: type, items: []T) !void {
    const count = items.len;
    var i: i8 = 1;
    print("[", .{});
    for (items) |item| {
        try item.stringify();
        if (i < count) {
            try printComma();
        }
        i += 1;
    }
    print("] ", .{});
}

pub fn printComma() !void {
    print(", ", .{});
}

pub fn getYesNo(boolean: bool) ![]const u8 {
    return switch (boolean) {
        true => "Yes",
        false => "No",
    };
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

    pub fn addOutput(self: *Parser, chars: []u8, offset: usize) !void {
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

    pub fn updateKey(self: *Parser, itemKey: []const u8) !void {
        var newKey: []u8 = &[_]u8{};
        var depthCounter: u32 = 0;
        var keySplit = std.mem.splitAny(u8, self.key, ".");
        _ = keySplit.next();
        while (depthCounter < self.depth) {
            if (keySplit.next()) |keyPart| {
                newKey = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{newKey, keyPart});
            }
            depthCounter += 1;
        }
        newKey = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{newKey, itemKey});
        self.allocator.free(self.key);
        self.key = newKey[0..];
    }

    pub fn parse(self: *Parser, char: u8) !void {
        try self.addChar(char);
        const charString: [1]u8 = [1]u8{char};
        var printBuff = try std.fmt.allocPrint(self.allocator, "{s}", .{charString});
        try self.addOutput(printBuff[0..], 0);
        // list item
        if (self.isBrackets and char == 44) {
            printBuff = try std.fmt.allocPrint(self.allocator, "<list-item-end>", .{});
            try self.addOutput(printBuff[0..], 0);
        }
        // value close
        if (self.isValue and (
            (!self.isSql and self.valueTerminatorChar == char)
            or (self.chars.len > 1
                and self.isSql
                and self.valueTerminatorChar == char
                and self.chars[self.chars.len - 2] == self.valueTerminatorChar)
            or (self.chars.len > 1
                and self.isNonQuoted
                and (self.valueTerminatorChar == char or char == 10)))) {
            
            if (char == 32 or char == 10) {
                self.removeOutputLastChars(1);
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
                    try self.includes.append(trimString(self.chars));
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
                printBuff = try std.fmt.allocPrint(self.allocator, "#!list", .{});
                try self.addOutput(printBuff[0..], 0);
            }
            // sql close
            if (self.isSql) {
                self.isSql = false;
                printBuff = try std.fmt.allocPrint(self.allocator, "#!sql", .{});
                try self.addOutput(printBuff[0..], 0);
            }
            // quotes close
            if (self.isQuoted) {
                self.isQuoted = false;
                printBuff = try std.fmt.allocPrint(self.allocator, "#!quotes", .{});
                try self.addOutput(printBuff[0..], 0);
            }
            // non quoted close
            if (self.isNonQuoted) {
                self.isNonQuoted = false;
                printBuff = try std.fmt.allocPrint(self.allocator, "#!nonquoted", .{});
                try self.addOutput(printBuff[0..], 0);
            }
            
            // reset the rest
            self.lastKey = &[_]u8{};
            self.isValue = false;
            self.valueTerminatorChar = 0;
            self.chars = &[_]u8{};
            printBuff = try std.fmt.allocPrint(self.allocator, "</{s}>", .{self.key});
            try self.addOutput(printBuff[0..], 0);
            return;
        }
        if (!self.isQuoted and !self.isBrackets and !self.isNonQuoted and !self.isSql) {
            // curly braces open
            if (char == 123) {
                self.removeOutputLastChars(1);
                if (self.isValue) {
                    self.isValue = false;
                    // printBuff = try std.fmt.allocPrint(self.allocator, "<nested-value>", .{});
                    // try self.addOutput(printBuff[0..], 0);
                }
                self.depth += 1;
                if (self.chars.len > 1 and self.chars[self.chars.len - 2] == 36) {
                    self.isVariable = true;
                }
                self.chars = &[_]u8{};
                return;
            }

            // curly braces close
            if (char == 125) {
                self.removeOutputLastChars(1);
                self.depth -= 1;
                if (self.isVariable) {
                    self.isVariable = false;
                }
                const last_closed_key = self.stack.pop();
                var is_captured = false;
                if (eq(last_closed_key, "view")) {
                    printBuff = try std.fmt.allocPrint(self.allocator, "\n\n#######\n", .{});
                    try self.addOutput(printBuff[0..], 0);
                    var dimensions = std.ArrayList([]const u8).init(self.allocator);
                    var dimension_groups = std.ArrayList([]const u8).init(self.allocator);
                    var measures = std.ArrayList([]const u8).init(self.allocator);
                    var filters = std.ArrayList([]const u8).init(self.allocator);
                    var parameters = std.ArrayList([]const u8).init(self.allocator);
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
                            }
                        }
                    }
                    
                    if (dimensions.items.len > 0) {
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}\"dimensions\": [", .{self.currentViewChars});
                        for (dimensions.items) |item| {
                            self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}{{{s}}},", .{self.currentViewChars, item});
                        }
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}],", .{self.currentViewChars});
                    }
                    if (dimension_groups.items.len > 0) {
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}\"dimension_groups\": [", .{self.currentViewChars});
                        for (dimension_groups.items) |item| {
                            self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}{{{s}}},", .{self.currentViewChars, item});
                        }
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}],", .{self.currentViewChars});
                    }
                    if (measures.items.len > 0) {
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}\"measures\": [", .{self.currentViewChars});
                        for (measures.items) |item| {
                            self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}{{{s}}},", .{self.currentViewChars, item});
                        }
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}],", .{self.currentViewChars});
                    }
                    if (filters.items.len > 0) {
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}\"filters\": [", .{self.currentViewChars});
                        for (filters.items) |item| {
                            self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}{{{s}}},", .{self.currentViewChars, item});
                        }
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}],", .{self.currentViewChars});
                    }
                    if (parameters.items.len > 0) {
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}\"parameters\": [", .{self.currentViewChars});
                        for (parameters.items) |item| {
                            self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}{{{s}}},", .{self.currentViewChars, item});
                        }
                        self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s}],", .{self.currentViewChars});
                    }
                    // self.currentViewChars = try std.fmt.allocPrint(self.allocator, "{s},{{{s}}}", .{self.currentViewChars, item});
                    try self.views.append(self.currentViewChars);
                    self.currentViewChars = &[_]u8{};
                    self.fields.clearAndFree();
                    is_captured = true;
                }
                if (!is_captured and isInList(last_closed_key, &fields)) {
                    self.currentFieldChars = try std.fmt.allocPrint(self.allocator, "{s}<###>{s}", .{last_closed_key, self.currentFieldChars, });
                    try self.fields.append(self.currentFieldChars);
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
                // try self.updateKey(key);

                // if (eq(key, "view")) {
                //     // if (self.views.len == 0) {
                //     //     self.views = "views: [";
                //     // }
                // }
                
                printBuff = try std.fmt.allocPrint(self.allocator, "\n", .{});
                for (self.stack.items) |item| {
                    printBuff = try std.fmt.allocPrint(self.allocator, "{s}{s}/", .{printBuff, item});
                }

                try self.addOutput(printBuff[0..], key.len+1);
                // printBuff = try std.fmt.allocPrint(self.allocator, keyValueDelimiter, .{});
                // try self.addOutput(printBuff, 1);
                self.lastKey = key;
                const keyLen: u16 = @intCast(key.len);
                self.removeOutputLastChars(keyLen + 1);
                self.isValue = true;
                self.chars = &[_]u8{};
                return;
            }

            // brackets open
            if (char == 91) {
                self.isBrackets = true;
                self.valueTerminatorChar = 93;
                self.chars = &[_]u8{};
                // printBuff = try std.fmt.allocPrint(self.allocator, "<list-start>", .{});
                // try self.addOutput(printBuff[0..], 0);
                return;
            }

            // quotes open
            if (char == 34 or char == 39) {
                self.valueTerminatorChar = char;
                self.isQuoted = true;
                // printBuff = try std.fmt.allocPrint(self.allocator, "<quotes-start>", .{});
                // try self.addOutput(printBuff[0..], 0);
                return;
            }

            // first char of value is not quote or bracket
            if (self.isValue and char != 32) {
                self.isSql = keyContainsSql(self.lastKey);
                if (self.isSql) {
                    self.valueTerminatorChar = 59;
                    // printBuff = try std.fmt.allocPrint(self.allocator, "<sql-start>", .{});
                    // try self.addOutput(printBuff[0..], 0);
                } else {
                    self.isNonQuoted = true;
                    self.valueTerminatorChar = 32;
                    // printBuff = try std.fmt.allocPrint(self.allocator, "<nonquoted-start>", .{});
                    // try self.addOutput(printBuff[0..], 0);
                }
                return;
            }

            // unnecessary space or newline
            if (char == 32 or char == 10) {
                self.removeOutputLastChars(1);
            }
        }
    }
};

pub fn eq(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub const KeyValue = struct{
    depth: u8,
    key: []const u8,
    val: []const u8,
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

    // var lkml = try Lkml.init(allocator, filePath);
    var parser = try Parser.init(allocator);
    var chars = std.mem.window(u8, readBuf, 1, 1);
    while (chars.next()) |char| {
        try parser.parse(char[0]);
    }

    print("{{", .{});

    if (parser.includes.items.len > 0) {
        print("\"includes\": [", .{});
        for (parser.includes.items) |item| {
            print("{s},", .{item});
        }
        print("],", .{});
    }
    if (parser.views.items.len > 0) {
        print("\"views\": [", .{});
        for (parser.views.items) |item| {
            print("{{{s}}},", .{item});
        }
        print("],", .{});
    } 
    print("}}", .{});
}
