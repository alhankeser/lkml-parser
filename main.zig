const std = @import("std");
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const print = std.debug.print;

const keyValueDelimiter = "|||";

// const LkmlObject = union(enum) {
//     lkml: Lkml,
//     view: View,
//     explore: Explore,
// };

// pub const AddItemReturnType = struct{
//     name: []const u8,
//     object: LkmlObject
// };

// pub const DepthLookup = enum(u2) {
//     Zero = 0,
//     One = 1,
//     Two = 2,
// };

var lkmlParams = [_][]const u8{ "view", "explore", "include", "extends" };
var viewParams = [_][]const u8{ "label", "extension", "sql_table_name", "drill_fields", "suggestions", "fields_hidden_by_default", "extends", "required_access_grants", "derived_table", "filter", "parameter", "dimension", "dimension_group", "measure", "set" };
var paramNames = [_][]const u8{ "action", "alias", "allow_approximate_optimization", "allow_fill", "allowed_value", "alpha_sort", "approximate", "approximate_threshold", "bypass_suggest_restrictions", "can_filter", "case", "case_sensitive", "convert_tz", "datatype", "default_value", "description", "direction", "drill_fields", "end_location_field", "fanout_on", "fields", "filters", "full_suggestions", "group_item_label", "group_label", "hidden", "html", "intervals", "label", "label_from_parameter", "link", "list_field", "map_layer_name", "order_by_field", "percentile", "precision", "primary_key", "required_access_grants", "required_fields", "skip_drill_filter", "sql", "sql_distinct_key", "sql_end", "sql_latitude", "sql_longitude", "sql_start", "start_location_field", "string_datatype", "style", "suggest_dimension", "suggest_explore", "suggest_persist_for", "suggestable", "suggestions", "tags", "tiers", "timeframes", "type", "units", "value_format", "value_format_name", "view_label" };

pub fn isValidKey(needle: []const u8, haystack: [][]const u8) bool {
    for (haystack) |thing| {
        if (equalStrings(needle, thing)) {
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

pub const Lkml = struct {
    allocator: Allocator,
    filename: []const u8,
    includes: [][]const u8,
    extends: [][]const u8,
    views: []View,
    explores: []Explore,
    objectIndex: usize,

    pub fn init(allocator: Allocator, filename: []const u8) !Lkml {
        return .{
            .allocator = allocator,
            .filename = filename,
            .includes = try allocator.alloc([]const u8, 0),
            .extends = try allocator.alloc([]const u8, 0),
            .views = try allocator.alloc(View, 0),
            .explores = try allocator.alloc(Explore, 0),
            .objectIndex = 0,
        };
    }

    pub fn stringify(self: Lkml) void {
        try printComma();
        print("\"filename\": \"{s}\", ", .{self.filename});
        print("\"includes\": ", .{});
        try printStrings(self.includes);
        try printComma();
        print("\"views\": ", .{});
        try printObjects(View, self.views);
    }

    pub fn addInclude(self: *Lkml, include: []const u8) !void {
        const T = @TypeOf(include);
        self.includes = try self.add([]T, T, self.includes, include);
    }

    pub fn addExtend(self: *Lkml, extend: []const u8) !void {
        const T = @TypeOf(extend);
        self.extends = try self.add([]T, T, self.extends, extend);
    }

    pub fn addView(self: *Lkml, view: View) !void {
        const T = @TypeOf(view);
        self.views = try self.add([]T, T, self.views, view);
    }

    pub fn addExplore(self: *Lkml, explore: Explore) !void {
        const T = @TypeOf(explore);
        self.explores = try self.add([]T, T, self.explores, explore);
    }

    pub fn addItem(self: *Lkml, depth: usize, key: []const u8, val: []const u8, valType: []const u8) !void {
        print("{any}, {s}, {s}, {s}", .{depth, key, val, valType});
        var objectType: []const u8 = undefined;
        var field: []const u8 = undefined;
        var param: []const u8 = undefined;
        var keySplit = std.mem.splitSequence(u8, key, ".");
        if (depth == 0) {
            if (equalStrings(key, "include")) {
                try self.addInclude(val);
            }
            if (equalStrings(key, "extend")) {
                try self.addExtend(val);
            }
            if (equalStrings(key, "view")) {
                const view = try View.init(self.allocator, val);
                try self.addView(view);
                self.objectIndex = self.views.len - 1;
            }
            if (equalStrings(key, "explore")) {
                const explore = try Explore.init(self.allocator, val);
                try self.addExplore(explore);
                self.objectIndex = self.explores.len - 1;
            }
            return;
        }
        if (depth == 1) {
            
            if (keySplit.next()) |res| {
                objectType = res;
            }
            if (keySplit.next()) |res| {
                field = res;
            }

            const isView = equalStrings(objectType, "view");
            const isExplore = equalStrings(objectType, "explore");

            if (isView and equalStrings(field, "dimension")) {
                var dim = try Field.init(self.allocator, val);
                try self.views[self.objectIndex].addDimension(dim);
                dim.name = dim.name;
                return;
            }

            if (isView and equalStrings(field, "label")) {
                self.views[self.objectIndex].label = val;
                return;
            }

            if (isView and equalStrings(field, "sql_table_name")) {
                self.views[self.objectIndex].sqlTableName = val;
                return;
            }

            if (isExplore and equalStrings(field, "name")) {
                self.explores[self.objectIndex].name = val;
                return;
            }
        }
        if (depth == 2) {
            param = "test";
        }
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
    dimensions: []Field,

    pub const StringAttribute = enum {
        Name,
        Label,
        // Description,
        Extension,
        SqlTableName,
        DrillFields,
    };

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
            .dimensions = try allocator.alloc(Field, 0),
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
        try printComma();
        print("\"dimensions\":", .{});
        try printObjects(Field, self.dimensions);
        // try self.derivedTable.stringify();
        print("}}", .{});
    }

    pub fn setStringAttribute(self: *View, attribute: StringAttribute, val: []const u8) !void {
        switch (attribute) {
            .Name => self.name = val,
            .Label => self.label = val,
            // .Description => self.description = val,
            .Extension => self.extension = val,
            .SqlTableName => self.sqlTableName = val,
            .DrillFields => self.drillFields = val,
        }
    }

    pub fn addLabel(self: *View, val: []const u8) !void {
        self.label = val;
    }

    pub fn addDimension(self: *View, dim: Field) !void {
        const T = @TypeOf(dim);
        self.dimensions = try self.add([]T, T, self.dimensions, dim);
    }

    fn add(self: *View, srcType: type, itemType: type, src: srcType, item: itemType) !srcType {
        const count = src.len + 1;
        var more = try self.allocator.alloc(itemType, count);
        std.mem.copyForwards(itemType, more[0..count], src);
        more[src.len] = item;
        self.allocator.free(src);
        return more;
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

pub const Field = struct {
    allocator: Allocator,
    name: []const u8,
    
    pub fn init(allocator: Allocator, name: []const u8) !Field {
        return .{
            .allocator = allocator,
            .name = name,
        };
    }
    pub fn stringify(self: Field) !void {
        print("{{\"name\": \"{s}\"}}", .{self.name});
    }
};

pub const Explore = struct {
    allocator: Allocator,
    name: []const u8,

    pub fn init(allocator: Allocator, name: []const u8) !Explore {
        return .{
            .allocator = allocator,
            .name = name,
        };
    }
};

pub fn isEven(n: u32) bool {
    return n & 1 == 0;
}

pub const Parser = struct {
    allocator: Allocator,
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

    pub fn init(allocator: Allocator) !Parser {
        return .{
            .allocator = allocator,
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
        // if (self.isBrackets and char == 44) {
        //     printBuff = try std.fmt.allocPrint(self.allocator, "<list-item-end>", .{});
        //     try self.addOutput(printBuff[0..], 0);
        // }
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
            // printBuff = try std.fmt.allocPrint(self.allocator, "</{s}>", .{self.key});
            // try self.addOutput(printBuff[0..], 0);
            return;
        }
        if (!self.isQuoted and !self.isBrackets and !self.isNonQuoted and !self.isSql) {
            // curly braces open
            if (char == 123) {
                self.removeOutputLastChars(1);
                if (self.isValue) {
                    self.isValue = false;
                    printBuff = try std.fmt.allocPrint(self.allocator, "nested-value", .{});
                    try self.addOutput(printBuff[0..], 0);
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
                self.chars = &[_]u8{};
                return;
            }

            // key
            if (!self.isValue and char == 58 and (self.chars[0] == 32 or self.chars[0] == 10 or self.chars.len == self.totalChars)) {
                var key = trimString(self.chars[0..]);
                key = key[0..key.len-1];
                try self.updateKey(key);
                // self.key = try std.fmt.allocPrint(self.allocator, "{any}.{s}", .{self.depth,key});
                
                printBuff = try std.fmt.allocPrint(self.allocator, "\n<{s}>", .{self.key});
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

pub fn equalStrings(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub const KeyValue = struct{
    key: []const u8,
    val: []const u8,
};



fn isInList(list: std.ArrayList([]const u8), item: []const u8) bool {
    for (list.items) |elem| {
        if (std.mem.eql(u8, item, elem)) {
            return true;
        }
    }
    return false;
}

// pub const Lkml = struct {
//     allocator: Allocator,
//     // objects: std.ArrayList(KeyValue),
//     keys: std.StringHashMap([]const u8),

//     pub fn init(allocator: Allocator) !Lkml {
//         return .{
//             .allocator = allocator,
//             // .objects = std.ArrayList(KeyValue).init(allocator),
//             .keys = std.StringHashMap([]const u8).init(allocator),
//         };
//     }

//     pub fn add(self: *Lkml, depth: usize, key: []const u8, val: []const u8, valType: []const u8) !void {
//         print("{any}, {s}, {s}, {s}", .{depth, key, val, valType});
//         if (depth == 0 and self.keys.contains(key)) {

//         } else {
//             // const keyValue = KeyValue{.key = key, .val = val};
//             try self.keys.put(key, val);
//         }
//         // try self.objects.append(keyValue); 
//     }
// };



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
    var parser = try Parser.init(allocator);
    var chars = std.mem.window(u8, readBuf, 1, 1);
    while (chars.next()) |char| {
        try parser.parse(char[0]);
    }
    const parsed: []u8 = parser.output;

    // print("{s}", .{parsed});
    var output: []u8 = &[_]u8{};
    var mainSplit = std.mem.splitSequence(u8, parsed, "<.");
    
    
    output = try std.fmt.allocPrint(allocator, "{s}{s}", .{output,"{"});
    defer allocator.free(output);
    while (mainSplit.next()) |item| {
        var itemSplit = std.mem.splitSequence(u8, item, ">");
        if (itemSplit.next()) |key| {
            const depth = std.mem.count(u8, key, ".");
            if (itemSplit.next()) |valWrapper| {
                var valSplit = std.mem.splitSequence(u8, valWrapper, "#!");
                if (valSplit.next()) |val| {
                    // print("{s}\n", .{val});
                    if (valSplit.next()) |valType| {
                        try lkml.addItem(depth, key, val, valType);
                        // print("type: {s}\n", .{valType});
                    }
                }
            }

            if (depth == 0 and isValidKey(key, &lkmlParams)) {
                
            }
            // print("{s}({any})\n", .{key, depth});
            // var keySplit()
        }
       
        
        // print("{s}\n", .{item});
    }
    output = try std.fmt.allocPrint(allocator, "{s}{s}", .{output,"}"});

    // _ = try getKeyValues(allocator, parsed, 0, &lkml);
    
    lkml.stringify();

    // print("{s}", .{output});
    // var it = lkml.keys.valueIterator();
    // while (it.next()) |key| {
    //     print("{s}\n", .{key});
    // }

}
