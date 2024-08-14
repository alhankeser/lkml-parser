const std = @import("std");
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const print = std.debug.print;

const objectNames = [2][]const u8{ "view:", "explore:" };
const fieldNames = [6][]const u8{ "filter:", "parameter:", "dimension:", "dimension_group:", "measure:", "set:" };
const paramNames = [62][]const u8{ "action:", "alias:", "allow_approximate_optimization:", "allow_fill:", "allowed_value:", "alpha_sort:", "approximate:", "approximate_threshold:", "bypass_suggest_restrictions:", "can_filter:", "case:", "case_sensitive:", "convert_tz:", "datatype:", "default_value:", "description:", "direction:", "drill_fields:", "end_location_field:", "fanout_on:", "fields:", "filters:", "full_suggestions:", "group_item_label:", "group_label:", "hidden:", "html:", "intervals:", "label:", "label_from_parameter:", "link:", "list_field:", "map_layer_name:", "order_by_field:", "percentile:", "precision:", "primary_key:", "required_access_grants:", "required_fields:", "skip_drill_filter:", "sql:", "sql_distinct_key:", "sql_end:", "sql_latitude:", "sql_longitude:", "sql_start:", "start_location_field:", "string_datatype:", "style:", "suggest_dimension:", "suggest_explore:", "suggest_persist_for:", "suggestable:", "suggestions:", "tags:", "tiers:", "timeframes:", "type:", "units:", "value_format:", "value_format_name:", "view_labe:l" };

pub fn isValidKey(keyType: i8, needle: []const u8) bool {
    const haystack: []const []const u8 = switch (keyType) {
        0 => &objectNames,
        1 => &fieldNames,
        2 => &paramNames,
        else => return false,
    };
    for (haystack) |thing| {
        if (std.mem.eql(u8, needle, thing)) {
            return true;
        }
    }
    return false;
}

pub const Lkml = struct {
    filepath: []const u8,
    views: []View,
    allocator: Allocator,
    includes: [][]const u8,

    pub fn init (allocator: Allocator, filepath: []const u8) !Lkml {
        return .{
            .allocator = allocator,
            .filepath = filepath,
            .includes = try allocator.alloc([]const u8, 0),
            .views = try allocator.alloc(View, 0),
        };
    }

    pub fn add (self: Lkml, view: View) !Lkml {
        const viewCount = self.views.len + 1;
        var more = try self.allocator.alloc(View, viewCount);
        std.mem.copyForwards(View, more[0..viewCount], self.views);
        more[self.views.len] = view;
        self.allocator.free(self.views);
        return Lkml {
            .allocator = self.allocator,
            .filepath = self.filepath,
            .includes = self.includes,
            .views = more,
        };
    }
};

pub const View = struct {
    allocator: Allocator,
    name: []const u8,
    label: []const u8,
    extension: []const u8,
    extends: [][]const u8,
    sqlTableName: []const u8,
    drillFields: []const u8,
    fieldsHiddenByDefault: bool,
    suggestions: bool,
    requiredAccessGrants: [][]const u8,
    derivedTable: DerivedTable,


    pub fn init (allocator: Allocator, name: []const u8) !View {
        return .{
            .allocator = allocator,
            .name = name,
            .label = "",
            .extension = "",
            .extends = try allocator.alloc([]const u8, 0),
            .sqlTableName = "",
            .drillFields = "",
            .fieldsHiddenByDefault = false,
            .suggestions = true,
            .requiredAccessGrants = try allocator.alloc([]const u8, 0),
            .derivedTable = try DerivedTable.init(allocator),
        };
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
};

pub const ExploreSource = struct {
    pub fn init() !ExploreSource {
        return .{};
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

    var lkml = try Lkml.init(allocator, filePath);

    const orders = try View.init(allocator, "orders");
    const customers = try View.init(allocator, "customers");
    const products = try View.init(allocator, "products");
    const pages = try View.init(allocator, "pages");
    lkml = try lkml.add(orders);
    lkml = try lkml.add(customers);
    lkml = try lkml.add(products);
    lkml = try lkml.add(pages);

    for (lkml.views) |view| {
        print("{s}\n", .{view.name});
    }

    // var isComment = false;
    // var quotesOpen = false;
    // var quoteChar: []const u8 = "\"";
    // var isKey = true;
    // var isPreviousObjectKey = false;
    // var isInObject = false;
    // var isExpectingObjectClosing = false;

    // var isPreviousFieldKey = false;
    // var isInField = false;
    // var isExpectingFieldClosing = false;

    // var isInParam: bool = false;
    // var isQuoteOpen: bool = false;
    // var isVariable: bool = false;
    // var quoteChar: []const u8 = undefined;
    // var previousChar: []const u8 = undefined;
    // var it = std.mem.split(u8, readBuf, " ");
    // while (it.next()) |word| {

    //     // object
    //     if (!isInObject and isValidKey(0, word)) {
    //         // close object
    //         if (isExpectingObjectClosing) {
    //             isExpectingObjectClosing = false;
    //             print("{s}", .{"\n}"});
    //         }
    //         print("\"{s}\": {{\n", .{word});
    //         isPreviousObjectKey = true;
    //         continue;
    //     }

    //     // field
    //     if (isInObject and !isQuoteOpen and isValidKey(1, word)) {
    //         if (isInParam) {
    //             isInParam = false;
    //             print("\\{s},\n", .{"\""});
    //         }
    //         // close field
    //         if (isExpectingFieldClosing) {
    //             isExpectingFieldClosing = false;
    //             print("{s}", .{",\n"});
    //         }
    //         print("  \"{s}\": {{\n", .{word});
    //         isPreviousFieldKey = true;
    //         continue;
    //     }

    //     // object name
    //     if (isPreviousObjectKey) {
    //         print("  \"name\": \"{s}\",\n", .{word});
    //         isPreviousObjectKey = false;
    //         isExpectingObjectClosing = true;
    //         isInObject = true;
    //         continue;
    //     }

    //     // field name
    //     if (isPreviousFieldKey) {
    //         print("    \"name\": \"{s}\",\n", .{word});
    //         isPreviousFieldKey = false;
    //         isExpectingFieldClosing = true;
    //         isInField = true;
    //         continue;
    //     }

    //     // param
    //     if (isInObject and isInField and !isQuoteOpen and isValidKey(2, word)) {
    //         if (isInParam) {
    //             print("{s}", .{"\",\n"});
    //         }
    //         print("    \"{s}\": \"", .{word});
    //         isInParam = true;
    //         continue;
    //     }

    //     if (isInParam) {
    //         var chars = std.mem.window(u8, word, 1, 1);
    //         while (chars.next()) |char| {
    //             if (std.mem.eql(u8, char, "'") or std.mem.eql(u8, char, "\"")) {
    //                 if (!isQuoteOpen) {
    //                     isQuoteOpen = true;
    //                     quoteChar = char;
    //                     std.debug.print("\\{s}", .{quoteChar});
    //                     continue;
    //                 }
    //                 if (isQuoteOpen and std.mem.eql(u8, char, quoteChar)) {
    //                     isQuoteOpen = false;
    //                     std.debug.print("\\{s}", .{quoteChar});
    //                     continue;
    //                 }
    //             }
    //             // Close variable
    //             if (isVariable and std.mem.eql(u8, char, "}")) {
    //                 isVariable = false;
    //                 print("{s}", .{char});
    //                 continue;
    //             }
    //             // Open variable
    //             if (!isVariable and std.mem.eql(u8, previousChar, "$") and std.mem.eql(u8, char, "{")) {
    //                 isVariable = true;
    //             }
    //             // Quote final param value
    //             if (isInParam and !isVariable and isExpectingFieldClosing and std.mem.eql(u8, char, "}")) {
    //                 print("\"{s}", .{""});
    //                 isInParam = false;
    //             }
    //             if (!std.mem.eql(u8, char, "\n")) {
    //                 print("{s}", .{char});
    //             }
    //             previousChar = char;
    //             if (!isInParam) {
    //                 break;
    //             }
    //         }
    //         if (!std.mem.eql(u8, previousChar, "}")) {
    //             print("{s}", .{" "});
    //         }
    //     }
    // }
    // if (isExpectingFieldClosing) {
    //     isExpectingFieldClosing = false;
    //     // print("{s}", .{"\n  }"});
    // }
    // if (isExpectingObjectClosing) {
    //     isExpectingObjectClosing = false;
    //     print("{s}", .{"\n}"});
    // }
}
