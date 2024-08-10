const std = @import("std");
const stdout = std.io.getStdOut().writer();
const print = std.debug.print;

pub fn isInArray(haystack: [2][]const u8, needle: []const u8) bool {
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

    
    const objectNames = [2][]const u8{ "view:", "explore:" };
    const fieldNames = [6][]const u8{ "filter:", "parameter:", "dimension:", "dimension_group:", "measure:", "set:" };
    const paramNames = [62][]const u8{
        "action:",
        "alias:",
        "allow_approximate_optimization:",
        "allow_fill:",
        "allowed_value:",
        "alpha_sort:",
        "approximate:",
        "approximate_threshold:",
        "bypass_suggest_restrictions:",
        "can_filter:",
        "case:",
        "case_sensitive:",
        "convert_tz:",
        "datatype:",
        "default_value:",
        "description:",
        "direction:",
        "drill_fields:",
        "end_location_field:",
        "fanout_on:",
        "fields:",
        "filters:",
        "full_suggestions:",
        "group_item_label:",
        "group_label:",
        "hidden:",
        "html:",
        "intervals:",
        "label:",
        "label_from_parameter:",
        "link:",
        "list_field:",
        "map_layer_name:",
        "order_by_field:",
        "percentile:",
        "precision:",
        "primary_key:",
        "required_access_grants:",
        "required_fields:",
        "skip_drill_filter:",
        "sql:",
        "sql_distinct_key:",
        "sql_end:",
        "sql_latitude:",
        "sql_longitude:",
        "sql_start:",
        "start_location_field:",
        "string_datatype:",
        "style:",
        "suggest_dimension:",
        "suggest_explore:",
        "suggest_persist_for:",
        "suggestable:",
        "suggestions:",
        "tags:",
        "tiers:",
        "timeframes:",
        "type:",
        "units:",
        "value_format:",
        "value_format_name:",
        "view_labe:l"
    };
    
    // var isComment = false;
    // var quotesOpen = false;
    // var quoteChar: []const u8 = "\"";
    // var isKey = true;
    var isPreviousObjectOrField = false;
    var isInObject = false;
    var isExpectingObjectClosingCurlyBraces = false;
    // var isInField = false;
    // var isInParameter = false;
    var it = std.mem.split(u8, readBuf, " ");
    while (it.next()) |word| {

        // object
        if (!isInObject and isInArray(objectNames, word)) {
            // close object
            if (isExpectingObjectClosingCurlyBraces) {
                isExpectingObjectClosingCurlyBraces = false;
                print("{s}", .{"\n}"});
            }
            print("\"{s}\" {{\n", .{word});
            isPreviousObjectOrField = true;
            continue;
        }
        // object name
        if (isPreviousObjectOrField) {
            print("  \"name\": \"{s}\"", .{word});
            isPreviousObjectOrField = false;
            isExpectingObjectClosingCurlyBraces = true;
            isInObject = true;
            continue;
        }
        
        // std.debug.print("{s}", .{word});
        // if (std.mem.eql(u8, char, "'") or std.mem.eql(u8, char, "\"")) {
        //     if (!quotesOpen) {
        //         quotesOpen = true;
        //         quoteChar = char;
        //         std.debug.print("{s}", .{"<quote open>"});
        //         continue;
        //     }
        //     if (quotesOpen and std.mem.eql(u8, char, quoteChar)) {
        //         quotesOpen = false;
        //         std.debug.print("{s}", .{"<quote close>"});
        //         continue;
        //     }
        // }
        // if (std.mem.eql(u8, char, "\n") and !quotesOpen) {
        //     isKey = true;
        // }
    }
    if (isExpectingObjectClosingCurlyBraces) {
        isExpectingObjectClosingCurlyBraces = false;
        print("{s}", .{"\n}"});
    }
    // _ = objectNames;
    _ = fieldNames;
    _ = paramNames;
}
