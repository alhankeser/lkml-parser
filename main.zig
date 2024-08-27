const std = @import("std");
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const print = std.debug.print;

const keyValueDelimiter = "|||";

const LkmlObject = union(enum) {
    lkml: Lkml,
    view: View,
    explore: Explore,
};

pub const AddItemReturnType = struct{
    name: []const u8,
    object: LkmlObject
};

pub const DepthLookup = enum(u2) {
    Zero = 0,
    One = 1,
    Two = 2,
};

var lkmlParams = [_][]const u8{ "view:", "explore:", "include:", "extends:" };
var viewParams = [_][]const u8{ "label:", "extension:", "sql_table_name:", "drill_fields:", "suggestions:", "fields_hidden_by_default:", "extends:", "required_access_grants:", "derived_table:", "filter:", "parameter:", "dimension:", "dimension_group:", "measure:", "set:" };
var paramNames = [_][]const u8{ "action:", "alias:", "allow_approximate_optimization:", "allow_fill:", "allowed_value:", "alpha_sort:", "approximate:", "approximate_threshold:", "bypass_suggest_restrictions:", "can_filter:", "case:", "case_sensitive:", "convert_tz:", "datatype:", "default_value:", "description:", "direction:", "drill_fields:", "end_location_field:", "fanout_on:", "fields:", "filters:", "full_suggestions:", "group_item_label:", "group_label:", "hidden:", "html:", "intervals:", "label:", "label_from_parameter:", "link:", "list_field:", "map_layer_name:", "order_by_field:", "percentile:", "precision:", "primary_key:", "required_access_grants:", "required_fields:", "skip_drill_filter:", "sql:", "sql_distinct_key:", "sql_end:", "sql_latitude:", "sql_longitude:", "sql_start:", "start_location_field:", "string_datatype:", "style:", "suggest_dimension:", "suggest_explore:", "suggest_persist_for:", "suggestable:", "suggestions:", "tags:", "tiers:", "timeframes:", "type:", "units:", "value_format:", "value_format_name:", "view_label:" };

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

pub fn trim(T: type, chars: T) T {
    if (chars.len == 0) {
        return chars;
    }
    var start: u16 = 0;
    var end = chars.len - 1;
    while (start < chars.len and (chars[start] == 32 or chars[start] == 10)) {
        start += 1;
    }
    while (end > 0 and end > start and (chars[end] == 32 or chars[end] == 10)) {
        end -= 1;
    }
    return chars[start .. end + 1];
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
    pub const Depth = enum { Zero, One, Two };
    allocator: Allocator,
    filePath: []const u8,
    includes: [][]const u8,
    views: []View,
    explores: []Explore,
    depth: Depth,
    currentObject: union(Depth) {
        Zero: Lkml,
        One: union {
            View: View,
            Explore: Explore,
        },
        Two: Field,
    },

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

    pub fn addInclude(self: *Lkml, include: []const u8) !void {
        const T = @TypeOf(include);
        self.includes = try self.add([]T, T, self.includes, include);
    }

    pub fn addView(self: *Lkml, view: View) !void {
        const T = @TypeOf(view);
        self.views = try self.add([]T, T, self.views, view);
    }

    pub fn addExplore(self: *Lkml, explore: Explore) !void {
        const T = @TypeOf(explore);
        self.explores = try self.add([]T, T, self.explores, explore);
    }

    pub fn addItem(self: *Lkml, currentObjectType: []const u8, currentObject: LkmlObject, key: []const u8, val: []const u8) !AddItemReturnType {
        var objectType = currentObjectType;
        var object = currentObject;
        if (equalStrings(key, "include:")) {
            try self.addInclude(val);
        }
        if (equalStrings(key, "view:")) {
            const view = try View.init(self.allocator, val);
            try self.addView(view);
            objectType = "view";
            object = LkmlObject{.view = view};
        }
        if (equalStrings(key, "explore:")) {
            const explore = try Explore.init(self.allocator, val);
            try self.addExplore(explore);
            objectType = "explore";
            object = LkmlObject{.explore = explore};
        }
        const result = AddItemReturnType{.name = objectType, .object = object};
        return result;
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

    pub const StringAttribute = enum {
        Name,
        Label,
        Description,
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

    pub fn setStringAttribute(self: *View, attribute: StringAttribute, val: []const u8) !void {
        switch (attribute) {
            .Name => self.name = val,
            .Label => self.label = val,
            .Description => self.description = val,
            .Extension => self.Extension = val,
            .SqlTableName => self.SqlTableName = val,
            .DrillFields => self.DrillFields = val,
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
    pub fn init() !Field {
        return .{};
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
    lastKey: []u8,
    valueTerminatorChar: u8,
    output: []u8,

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
            .output = &[_]u8{}
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

    pub fn parse(self: *Parser, char: u8) !void {
        if (self.output.len == 0) {
            var printBuff = try std.fmt.allocPrint(self.allocator, "<depth-start:{any}>", .{self.depth});
            try self.addOutput(printBuff[0..], 0);
        }
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

            // brackets close
            if (self.isBrackets) {
                self.isBrackets = false;
                printBuff = try std.fmt.allocPrint(self.allocator, "<list-end>", .{});
                try self.addOutput(printBuff[0..], 0);
            }
            // sql close
            if (self.isSql) {
                self.isSql = false;
                // printBuff = try std.fmt.allocPrint(self.allocator, "<sql-end>", .{});
                // try self.addOutput(printBuff[0..], 0);
            }
            // quotes close
            if (self.isQuoted) {
                self.isQuoted = false;
                // printBuff = try std.fmt.allocPrint(self.allocator, "<quotes-end>", .{});
                // try self.addOutput(printBuff[0..], 0);
            }
            // non quoted close
            if (self.isNonQuoted) {
                self.isNonQuoted = false;
                // printBuff = try std.fmt.allocPrint(self.allocator, "<nonquoted-end>", .{});
                // try self.addOutput(printBuff[0..], 0);
            }
            // reset the rest
            self.lastKey = &[_]u8{};
            self.isValue = false;
            self.valueTerminatorChar = 0;
            self.chars = &[_]u8{};
            printBuff = try std.fmt.allocPrint(self.allocator, "<keyvalue-end:{any}>", .{self.depth});
            try self.addOutput(printBuff[0..], 0);
            return;
        }
        if (!self.isQuoted and !self.isBrackets and !self.isNonQuoted and !self.isSql) {
            // key
            if (!self.isValue and char == 58 and (self.chars[0] == 32 or self.chars[0] == 10 or self.chars.len == self.totalChars)) {
                const key = trim([]u8, self.chars[0..]);
                if (self.depth == 0 and isValidKey(key, &lkmlParams)) {
                    printBuff = try std.fmt.allocPrint(self.allocator, "<keyvalue-start:{any}>", .{self.depth});
                    try self.addOutput(printBuff[0..], key.len);
                    printBuff = try std.fmt.allocPrint(self.allocator, keyValueDelimiter, .{});
                    try self.addOutput(printBuff, 1);
                    self.lastKey = key;
                }
                if (self.depth == 1 and isValidKey(key, &viewParams)) {
                    printBuff = try std.fmt.allocPrint(self.allocator, "<keyvalue-start:{any}>", .{self.depth});
                    try self.addOutput(printBuff[0..], key.len);
                    printBuff = try std.fmt.allocPrint(self.allocator, keyValueDelimiter, .{});
                    try self.addOutput(printBuff, 1);
                    self.lastKey = key;
                }
                if (self.depth >= 2 and isValidKey(key, &paramNames)) {
                    printBuff = try std.fmt.allocPrint(self.allocator, "<keyvalue-start:{any}>", .{self.depth});
                    try self.addOutput(printBuff[0..], key.len);
                    printBuff = try std.fmt.allocPrint(self.allocator, keyValueDelimiter, .{});
                    try self.addOutput(printBuff, 1);
                    self.lastKey = key;
                }
                self.removeOutputLastChars(1);
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

            // curly braces open
            if (char == 123) {
                self.removeOutputLastChars(1);
                if (self.isValue) {
                    self.isValue = false;
                    printBuff = try std.fmt.allocPrint(self.allocator, "<nested-value><keyvalue-end:{any}>", .{self.depth});
                    try self.addOutput(printBuff[0..], 0);
                }
                // if (!self.isVariable and self.depth == 0) {
                //     printBuff = try std.fmt.allocPrint(self.allocator, "<depth-end:{any}>", .{self.depth});
                //     try self.addOutput(printBuff[0..], 0);
                // }
                self.depth += 1;
                if (!self.isVariable) {
                    printBuff = try std.fmt.allocPrint(self.allocator, "<depth-end:{any}><depth-start:{any}>", .{self.depth-1, self.depth});
                    try self.addOutput(printBuff[0..], 0);
                }
                if (self.chars.len > 1 and self.chars[self.chars.len - 2] == 36) {
                    self.isVariable = true;
                }
                self.chars = &[_]u8{};
                return;
            }

            // curly braces close
            if (char == 125) {
                self.removeOutputLastChars(1);
                if (!self.isVariable) {
                    if (self.isValue) {
                        printBuff = try std.fmt.allocPrint(self.allocator, "<keyvalue-end:{any}>", .{self.depth});
                        try self.addOutput(printBuff[0..], 0);
                    }
                    printBuff = try std.fmt.allocPrint(self.allocator, "<depth-end:{any}>", .{self.depth});
                    try self.addOutput(printBuff[0..], 0);
                }
                self.depth -= 1;
                if (!self.isVariable) {
                    printBuff = try std.fmt.allocPrint(self.allocator, "<depth-start:{any}>", .{self.depth});
                    try self.addOutput(printBuff[0..], 0);
                }
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
        }
    }

    pub fn finish(self: *Parser) !void {
        var printBuff = try std.fmt.allocPrint(self.allocator, "<depth-end:{any}>", .{self.depth});
        try self.addOutput(printBuff[0..], 0);
    }

    pub fn stringify(self: *Parser) !void {
        print("{s}", .{self.output});
    }
};

pub fn equalStrings(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub fn cleanVal(text: []const u8) []const u8 {
    return text;
}

pub fn getDepth(text: []const u8) !u32 {
    _ = text;
    return 1;
}

pub fn getDepthKey(allocator: Allocator, depth: u32) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "<depth-start:{any}>", .{depth});
}

pub const KeyValue = struct{
    depth: u8,
    key: []const u8,
    val: []const u8,
};

pub fn getKeyValue(allocator: Allocator, depth: u8, text: []const u8) !KeyValue {
    var keyValue: KeyValue = undefined;
    const keyvalSplitIndexOptional = std.mem.indexOfPos(u8, text, 0, keyValueDelimiter);
    const keyvalEndDelimiter = try std.fmt.allocPrint(allocator, "<keyvalue-end:{any}>", .{depth});
    // print("{s}\n\n", .{text});
    if (keyvalSplitIndexOptional) |keyvalSplitIndex| {
        const key = trim([]const u8, text[0..keyvalSplitIndex]);
        const keyvalEndIndexOptional = std.mem.indexOfPos(u8, text, 0, keyvalEndDelimiter);
        if (keyvalEndIndexOptional) |keyvalEndIndex| {
            const val = trim([]const u8, text[keyvalSplitIndex + keyValueDelimiter.len..keyvalEndIndex]);
            keyValue = KeyValue{.depth = depth, .key = key, .val = val};
        }
        print("depth:{any}\nkey:{s}\nval:{s}\n\n", .{keyValue.depth, keyValue.key, keyValue.val});
    }
    return keyValue;
}

pub fn getKeyValues(allocator: Allocator, text: []const u8, depth: u8,) ![]KeyValue {
    const depthStartKey = try std.fmt.allocPrint(allocator, "<depth-start:{any}>", .{depth});
    const depthStopKey = try std.fmt.allocPrint(allocator, "<depth-end:{any}>", .{depth});
    var depthStartSplit = std.mem.splitSequence(u8, text, depthStartKey);
    var keyValuesList = std.ArrayList(KeyValue).init(allocator);
    defer keyValuesList.deinit();
    while (depthStartSplit.next()) |depthChunk| {
        const depthStopIndexOptional = std.mem.indexOfPos(u8, depthChunk, 0, depthStopKey);
        if (depthStopIndexOptional) |depthStopIndex| {
            const keyValueStartDelimiter = try std.fmt.allocPrint(allocator, "<keyvalue-start:{any}>", .{depth});
            var keyValueTextSplit = std.mem.splitSequence(u8, depthChunk[0..depthStopIndex], keyValueStartDelimiter);
            while (keyValueTextSplit.next()) |keyValueText| {
                const keyval = try getKeyValue(allocator, depth, keyValueText);
                try keyValuesList.append(keyval);
            }
            const nextDepth = depth + 1;
            const nextDepthKey = try getDepthKey(allocator, nextDepth);
            if (depthChunk.len > (depthStopIndex + depthStopKey.len + nextDepthKey.len)){
                const nextDepthKeyString = depthChunk[depthStopIndex + depthStopKey.len..depthStopIndex + depthStopKey.len + nextDepthKey.len];
                if (equalStrings(nextDepthKey, nextDepthKeyString)) {
                    _ = try getKeyValues(allocator, depthChunk[depthStopIndex + depthStopKey.len..], nextDepth);
                }
            }
        }
    }
    return keyValuesList.items;
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

    // const lkml = try Lkml.init(allocator, filePath);
    var parser = try Parser.init(allocator);
    var chars = std.mem.window(u8, readBuf, 1, 1);

    while (chars.next()) |char| {
        try parser.parse(char[0]);
    }
    try parser.finish();

    const parsed: []u8 = parser.output;
    var key: []const u8 = &[_]u8{};
    var val: []const u8 = &[_]u8{};

    // print("{s}", .{parsed});
    print("\n\n", .{});
    // const keyValues: []KeyValue = undefined;

    _ = try getKeyValues(allocator, parsed, 0);
    // const depth: u8 = 0;
    // const depthStartKey = try std.fmt.allocPrint(allocator, "<depth-start:{any}>", .{depth});
    // const depthStopKey = try std.fmt.allocPrint(allocator, "<depth-end:{any}>", .{depth});
    // var depthStartIndexOptional = std.mem.indexOfPos(u8, parsed, 0, depthStartKey);
    // var depthStopIndexOptional = std.mem.indexOfPos(u8, parsed, 0, depthStopKey);
    // var subArray = parsed;

    // while (depthStartIndexOptional) |depthStartIndex| {
    //     if (depthStopIndexOptional) |depthStopIndex| {
    //         _ = try getKeyValues(allocator, depth, subArray[depthStartIndex + depthStartKey.len..depthStopIndex]);
    //         subArray = subArray[depthStopIndex+depthStopKey.len..];
    //         depthStartIndexOptional = std.mem.indexOfPos(u8, subArray, 0, depthStartKey);
    //         depthStopIndexOptional = std.mem.indexOfPos(u8, subArray, 0, depthStopKey);
    //     }
    // }
    // return keyValues;
    
    key = &[_]u8{};
    val = &[_]u8{};

    // currentObject.lkml.stringify();

}
