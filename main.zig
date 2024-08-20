const std = @import("std");
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const print = std.debug.print;

var lkmlParams = [_][]const u8{ "view:", "explore:", "include:", "extends:"};
var viewParms =  [_][]const u8{ "label:", "extension:", "sql_table_name:", "drill_fields:", "suggestions:", "fields_hidden_by_default:", "extends:", "required_access_grants:", "derived_table:", "filter:", "parameter:", "dimension:", "dimension_group:", "measure:", "set:" };
var paramNames = [_][]const u8{ "action:", "alias:", "allow_approximate_optimization:", "allow_fill:", "allowed_value:", "alpha_sort:", "approximate:", "approximate_threshold:", "bypass_suggest_restrictions:", "can_filter:", "case:", "case_sensitive:", "convert_tz:", "datatype:", "default_value:", "description:", "direction:", "drill_fields:", "end_location_field:", "fanout_on:", "fields:", "filters:", "full_suggestions:", "group_item_label:", "group_label:", "hidden:", "html:", "intervals:", "label:", "label_from_parameter:", "link:", "list_field:", "map_layer_name:", "order_by_field:", "percentile:", "precision:", "primary_key:", "required_access_grants:", "required_fields:", "skip_drill_filter:", "sql:", "sql_distinct_key:", "sql_end:", "sql_latitude:", "sql_longitude:", "sql_start:", "start_location_field:", "string_datatype:", "style:", "suggest_dimension:", "suggest_explore:", "suggest_persist_for:", "suggestable:", "suggestions:", "tags:", "tiers:", "timeframes:", "type:", "units:", "value_format:", "value_format_name:", "view_label:" };

pub fn isValidKey(needle: []const u8, haystack: [][]const u8) bool {
    for (haystack) |thing| {
        if (try equalStrings(needle, thing)) {
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
        false => "No"
    };
}

pub fn removeLeadingWhitespace(chars: []u8) []u8 {
    var start: u16 = 0;
    while (start < chars.len and (chars[start] == 32 or chars[start] == 10)) {
        start += 1;
    }
    return chars[start..];
}

pub fn keyContainsSql(key: []u8) bool {
    const index = std.mem.indexOf(u8, key, "sql");
    if (index) |idx| {
        _ = idx;
        return true;
    }
    return false;
}

pub const Lkml = struct {
    allocator: Allocator,
    filePath: []const u8,
    includes: [][]const u8,
    views: []View,
    explores: []Explore,

    pub fn init(allocator: Allocator, filePath: []const u8) !Lkml {
        return .{
            .allocator = allocator,
            .filePath = filePath,
            .includes = try allocator.alloc([]const u8, 0),
            .views = try allocator.alloc(View, 0),
            .explores = try allocator.alloc(Explore, 0),
        };
    }

    pub fn stringify(self: Lkml) void {
        try printComma();
        print("\"filepath\": \"{s}\", ", .{self.filePath});
        print("\"includes\": ", .{});
        try printStrings(self.includes);
        try printComma();
        print("\"views\": ", .{});
        try printObjects(View, self.views);
    }

    pub fn addInclude(self: *Lkml, include: []const u8) void {
        const T = @TypeOf(include);
        self.includes = try self.add([]T, T, self.includes, include);
    }

    pub fn addView(self: *Lkml, view: View) !void {
        const T = @TypeOf(view);
        self.views = try self.add([]T, T, self.views, view);
    }

    fn add(self: *Lkml, srcType: type, itemType: type, src: srcType, item: itemType) !srcType {
        const count = src.len + 1;
        var more = try self.allocator.alloc(itemType, count);
        std.mem.copyForwards(itemType, more[0..count], src);
        more[src.len] = item;
        self.allocator.free(src);
        return more;
    }
};

pub const View = struct {
    allocator: Allocator,
    name: []const u8,
    label: []const u8,
    extension: []const u8,
    sqlTableName: []const u8,
    drillFields: []const u8,
    suggestions: bool,
    fieldsHiddenByDefault: bool,
    extends: [][]const u8,
    requiredAccessGrants: [][]const u8,
    derivedTable: DerivedTable,


    pub fn init(allocator: Allocator, name: []const u8) !View {
        return .{
            .allocator = allocator,
            .name = name,
            .label = "",
            .extension = "",
            .sqlTableName = "",
            .drillFields = "",
            .suggestions = true,
            .fieldsHiddenByDefault = false,
            .extends = try allocator.alloc([]const u8, 0),
            .requiredAccessGrants = try allocator.alloc([]const u8, 0),
            .derivedTable = try DerivedTable.init(allocator),
        };
    }

    pub fn stringify(self: View) !void {
        print("{{", .{});
        print("\"name\": \"{s}\"", .{self.name});
        try printComma();
        print("\"label\": \"{s}\"", .{self.label});
        try printComma();
        print("\"extension\": \"{s}\"", .{self.extension});
        try printComma();
        print("\"sql_table_name\": \"{s}\"", .{self.sqlTableName});
        try printComma();
        print("\"drill_fields\": \"{s}\"", .{self.drillFields});
        try printComma();
        print("\"suggestions\": \"{s}\"", .{try getYesNo(self.suggestions)});
        try printComma();
        print("\"fields_hidden_by_default\": \"{s}\"", .{try getYesNo(self.fieldsHiddenByDefault)});
        try printComma();
        print("\"extends\": ", .{});
        try printStrings(self.extends);
        try printComma();
        print("\"required_access_grants\": ", .{});
        try printStrings(self.requiredAccessGrants);
        // try self.derivedTable.stringify();
        print("}}", .{});
    }

    pub fn updateName(self: *View, name: []const u8) !void {
        self.name = name;
    }
};

pub const DerivedTable = struct {
    allocator: Allocator,
    clusterKeys: [][]const u8,
    createProcess: []const u8,
    datagroupTrigger: []const u8,
    distribution: []const u8,
    distributionStyle: []const u8,
    exploreSource: ExploreSource,
    incrementKey: []const u8,
    incrementOffset: i16,
    indexes: [][]const u8,
    intervalTrigger: []const u8,
    materializedView: bool,
    partitionKeys: [][]const u8,
    persistFor: []const u8,
    publishAsDbView: bool,
    sortkeys: [][]const u8,
    sql: []const u8,
    sqlCreate: []const u8,
    sqlTriggerValue: []const u8,
    tableCompression: []const u8,
    tableFormat: []const u8,

    pub fn init(allocator: Allocator) !DerivedTable {
        return .{
            .allocator = allocator,
            .clusterKeys = try allocator.alloc([]const u8, 0),
            .createProcess = "",
            .datagroupTrigger = "",
            .distribution = "",
            .distributionStyle = "",
            .exploreSource = try ExploreSource.init(),
            .incrementKey = "",
            .incrementOffset = undefined,
            .indexes = try allocator.alloc([]const u8, 0),
            .intervalTrigger = "",
            .materializedView = undefined,
            .partitionKeys = try allocator.alloc([]const u8, 0),
            .persistFor = "",
            .publishAsDbView = undefined,
            .sortkeys = try allocator.alloc([]const u8, 0),
            .sql = "",
            .sqlCreate = "",
            .sqlTriggerValue = "",
            .tableCompression = "",
            .tableFormat = "",
        };
    }

    pub fn stringify() !void {
        print("Derived Table", .{});
    }
};

pub const ExploreSource = struct {
    pub fn init() !ExploreSource {
        return .{};
    }
};

pub const Explore = struct {
    name: []const u8,
    pub fn init() !Explore {
        return .{
            .name = "hello",
        };
    }
};

pub const Parser = struct {
    allocator: Allocator,
    lkml: Lkml,
    chars: []u8,
    totalChars: u32,
    depth: i8,
    isQuoted: bool,
    isNonQuoted: bool,
    isBrackets: bool,
    isVariable: bool,
    isValue: bool,
    isSql: bool,
    lastKey: []u8,
    valueTerminatorChar: u8,
    output: []u8,

    pub fn init(allocator: Allocator, lkml: Lkml) !Parser {
        return .{
            .allocator = allocator,
            .lkml = lkml,
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
            .output = &[_]u8{}
        };
    }

    pub fn addChar(self: *Parser, char: u8) !void {
        const size_needed = self.chars.len + 1;
        const buffer = try self.allocator.alloc(u8, size_needed);
        std.mem.copyForwards(u8, buffer[0..self.chars.len], self.chars);
        buffer[self.chars.len] = char;
        self.allocator.free(self.chars);
        self.chars = buffer[0..size_needed];
        self.totalChars += 1;
    }

    pub fn addOutput(self: *Parser, chars: []u8) !void {
        const size_needed = self.output.len + chars.len;
        const buffer = try self.allocator.alloc(u8, size_needed);
        std.mem.copyForwards(u8, buffer[0..self.output.len], self.output);
        std.mem.copyForwards(u8, buffer[self.output.len..size_needed], chars);
        self.allocator.free(self.output);
        self.output = buffer;
    }

    pub fn parse(self: *Parser, char: u8) !void {
        try self.addChar(char);
        const charString:[1]u8= [1]u8{char};
        var printBuff = try std.fmt.allocPrint(self.allocator, "{s}", .{charString});
        try self.addOutput(printBuff[0..]);
        // list item
        if (self.isBrackets and char == 44) {
            printBuff = try std.fmt.allocPrint(self.allocator, "<list-item-end>", .{});
            try self.addOutput(printBuff[0..]);
        }
        // value close
        if (self.isValue and (
            (
                !self.isSql 
                and self.valueTerminatorChar == char
            ) 
            or (
                self.chars.len > 1 
                and self.isSql 
                and self.valueTerminatorChar == char
                and self.chars[self.chars.len-2] == self.valueTerminatorChar
            )
            or (
                self.chars.len > 1 
                and self.isNonQuoted 
                and (self.valueTerminatorChar == char or char == 10)
            ))) {
            
            // brackets close
            if (self.isBrackets) {
                self.isBrackets = false;
                printBuff = try std.fmt.allocPrint(self.allocator, "<list-end>", .{});
                try self.addOutput(printBuff[0..]);
            }
            // sql close
            if (self.isSql) {
                self.isSql = false;
                printBuff = try std.fmt.allocPrint(self.allocator, "<sql-end>", .{});
                try self.addOutput(printBuff[0..]);
            }
            // quotes close
            if (self.isQuoted) {
                self.isQuoted = false;
                printBuff = try std.fmt.allocPrint(self.allocator, "<quotes-end>", .{});
                try self.addOutput(printBuff[0..]);
            }
            // non quoted close
            if (self.isNonQuoted) {
                self.isNonQuoted = false;
                printBuff = try std.fmt.allocPrint(self.allocator, "<nonquoted-end>", .{});
                try self.addOutput(printBuff[0..]);
            }
            // reset the rest
            self.lastKey = &[_]u8{};
            self.isValue = false;
            self.valueTerminatorChar = 0;
            self.chars = &[_]u8{};
            printBuff = try std.fmt.allocPrint(self.allocator, "<keyvalue-end:{any}>", .{self.depth});
            try self.addOutput(printBuff[0..]);
            return;
        }
        if (!self.isQuoted and !self.isBrackets and !self.isNonQuoted and !self.isSql) {
            // key
            if (!self.isValue and char == 58 and (self.chars[0] == 32 or self.chars[0] == 10 or self.chars.len == self.totalChars)) {
                const key = removeLeadingWhitespace(self.chars[0..]);
                if (self.depth == 0 and isValidKey(key, &lkmlParams)) {
                    printBuff = try std.fmt.allocPrint(self.allocator, "<keyvalue-start:{any}>", .{self.depth});
                    try self.addOutput(printBuff[0..]);
                    self.lastKey = key;
                }
                if (self.depth == 1 and isValidKey(key, &viewParms)) {
                    printBuff = try std.fmt.allocPrint(self.allocator, "<keyvalue-start:{any}>", .{self.depth});
                    try self.addOutput(printBuff[0..]);
                    self.lastKey = key;
                }
                if (self.depth == 2 and isValidKey(key, &paramNames)) {
                    printBuff = try std.fmt.allocPrint(self.allocator, "<keyvalue-start:{any}>", .{self.depth});
                    try self.addOutput(printBuff[0..]);
                    self.lastKey = key;
                }
                self.isValue = true;
                self.chars = &[_]u8{};
                return;
            }

            // brackets open
            if (char == 91) {
                self.isBrackets = true;
                self.valueTerminatorChar = 93;
                self.chars = &[_]u8{};
                printBuff = try std.fmt.allocPrint(self.allocator, "<list-start>", .{});
                try self.addOutput(printBuff[0..]);
                return;
            }
            
            // quotes open
            if (char == 34 or char == 39) {
                self.valueTerminatorChar = char;
                self.isQuoted = true;
                printBuff = try std.fmt.allocPrint(self.allocator, "<quotes-start>", .{});
                try self.addOutput(printBuff[0..]);
                return;
            }

            // curly braces open
            if (char == 123) {
                if (self.isValue) {
                    self.isValue = false;                    
                    printBuff = try std.fmt.allocPrint(self.allocator, "<keyvalue-end:{any}>", .{self.depth});
                    try self.addOutput(printBuff[0..]);
                }
                self.depth += 1;
                if (!self.isVariable) {
                    printBuff = try std.fmt.allocPrint(self.allocator, "<depth-start:{any}>", .{self.depth});
                    try self.addOutput(printBuff[0..]);
                }
                if (self.chars.len > 1 and self.chars[self.chars.len-2] == 36) {
                    self.isVariable = true;
                }
                self.chars = &[_]u8{};
                return;
            }

            // curly braces close
            if (char == 125) {
                if (!self.isVariable) {
                    printBuff = try std.fmt.allocPrint(self.allocator, "<depth-start:{}>", .{self.depth});
                    try self.addOutput(printBuff[0..]);
                }
                self.depth -= 1;
                if (self.isVariable) {
                    self.isVariable = false;
                }
                self.chars = &[_]u8{};
                return;
            }

            // first char of value is not quote or bracket
            if (self.isValue and char != 32) {
                self.isSql = keyContainsSql(self.lastKey);
                if (self.isSql) {
                    self.valueTerminatorChar = 59;
                    printBuff = try std.fmt.allocPrint(self.allocator, "<sql-start>", .{});
                    try self.addOutput(printBuff[0..]);
                } else {
                    self.isNonQuoted = true;
                    self.valueTerminatorChar = 32;
                    printBuff = try std.fmt.allocPrint(self.allocator, "<nonquoted-start>", .{});
                    try self.addOutput(printBuff[0..]);
                }
                return;
            }
        }
    }

    pub fn stringify(self: *Parser) !void {
        print("{s}", .{self.output});
    }
};

pub fn equalStrings(a: []const u8, b: []const u8) !bool {
    return std.mem.eql(u8, a, b);
}

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

    var lkml = try Lkml.init(allocator, filePath);
    var parser = try Parser.init(allocator, lkml);
    var chars = std.mem.window(u8, readBuf, 1, 1);

    while (chars.next()) |char| {
        try parser.parse(char[0]);
    }

    try parser.stringify();
    
    lkml.stringify();


    

    // try parser.stringify();

    
    // const orders = try View.init(allocator, "orders");
    // const customers = try View.init(allocator, "customers");
    

    

    // lkml.stringify();
}
