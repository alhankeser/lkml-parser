const std = @import("std");
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

    // var isComment = false;
    // var quotesOpen = false;
    // var quoteChar: []const u8 = "\"";
    // var isKey = true;
    var isPreviousObjectKey = false;
    var isInObject = false;
    var isExpectingObjectClosing = false;

    var isPreviousFieldKey = false;
    var isInField = false;
    var isExpectingFieldClosing = false;

    var isInParam: bool = false;
    var isQuoteOpen: bool = false;
    var isVariable: bool = false;
    var quoteChar: []const u8 = undefined;
    var previousChar: []const u8 = undefined;
    var it = std.mem.split(u8, readBuf, " ");
    while (it.next()) |word| {

        // object
        if (!isInObject and isValidKey(0, word)) {
            // close object
            if (isExpectingObjectClosing) {
                isExpectingObjectClosing = false;
                print("{s}", .{"\n}"});
            }
            print("\"{s}\": {{\n", .{word});
            isPreviousObjectKey = true;
            continue;
        }

        // field
        if (isInObject and !isQuoteOpen and isValidKey(1, word)) {
            if (isInParam) {
                isInParam = false;
                print("\\{s},\n", .{"\""});
            }
            // close field
            if (isExpectingFieldClosing) {
                isExpectingFieldClosing = false;
                print("{s}", .{",\n"});
            }
            print("  \"{s}\": {{\n", .{word});
            isPreviousFieldKey = true;
            continue;
        }

        // object name
        if (isPreviousObjectKey) {
            print("  \"name\": \"{s}\",\n", .{word});
            isPreviousObjectKey = false;
            isExpectingObjectClosing = true;
            isInObject = true;
            continue;
        }

        // field name
        if (isPreviousFieldKey) {
            print("    \"name\": \"{s}\",\n", .{word});
            isPreviousFieldKey = false;
            isExpectingFieldClosing = true;
            isInField = true;
            continue;
        }

        // param
        if (isInObject and isInField and !isQuoteOpen and isValidKey(2, word)) {
            if (isInParam) {
                print("{s}", .{"\",\n"});
            }
            print("    \"{s}\": \"", .{word});
            isInParam = true;
            continue;
        }

        if (isInParam) {
            var chars = std.mem.window(u8, word, 1, 1);
            while (chars.next()) |char| {
                if (std.mem.eql(u8, char, "'") or std.mem.eql(u8, char, "\"")) {
                    if (!isQuoteOpen) {
                        isQuoteOpen = true;
                        quoteChar = char;
                        std.debug.print("\\{s}", .{quoteChar});
                        continue;
                    }
                    if (isQuoteOpen and std.mem.eql(u8, char, quoteChar)) {
                        isQuoteOpen = false;
                        std.debug.print("\\{s}", .{quoteChar});
                        continue;
                    }
                }
                // Close variable
                if (isVariable and std.mem.eql(u8, char, "}")) {
                    isVariable = false;
                    print("{s}", .{char});
                    continue;
                }
                // Open variable
                if (!isVariable and std.mem.eql(u8, previousChar, "$") and std.mem.eql(u8, char, "{")) {
                    isVariable = true;
                }
                // Quote final param value
                if (isInParam and !isVariable and isExpectingFieldClosing and std.mem.eql(u8, char, "}")) {
                    print("\"{s}", .{""});
                    isInParam = false;
                }
                if (!std.mem.eql(u8, char, "\n")) {
                    print("{s}", .{char});
                }
                previousChar = char;
                if (!isInParam) {
                    break;
                }
            }
            if (!std.mem.eql(u8, previousChar, "}")) {
                print("{s}", .{" "});
            }
        }
    }
    if (isExpectingFieldClosing) {
        isExpectingFieldClosing = false;
        // print("{s}", .{"\n  }"});
    }
    if (isExpectingObjectClosing) {
        isExpectingObjectClosing = false;
        print("{s}", .{"\n}"});
    }
}
