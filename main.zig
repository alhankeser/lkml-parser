const std = @import("std");
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const print = std.debug.print;

const keyValueDelimiter = "|||";

var lkmlParams = [_][]const u8{ "view", "explore", "include", "extends" };
var viewParams = [_][]const u8{ "label", "extension", "sql_table_name", "drill_fields", "suggestions", "fields_hidden_by_default", "extends", "required_access_grants", "derived_table", "filter", "parameter", "dimension", "dimension_group", "measure", "set" };
var paramNames = [_][]const u8{ "action", "alias", "allow_approximate_optimization", "allow_fill", "allowed_value", "alpha_sort", "approximate", "approximate_threshold", "bypass_suggest_restrictions", "can_filter", "case", "case_sensitive", "convert_tz", "datatype", "default_value", "description", "direction", "drill_fields", "end_location_field", "fanout_on", "fields", "filters", "full_suggestions", "group_item_label", "group_label", "hidden", "html", "intervals", "label", "label_from_parameter", "link", "list_field", "map_layer_name", "order_by_field", "percentile", "precision", "primary_key", "required_access_grants", "required_fields", "skip_drill_filter", "sql", "sql_distinct_key", "sql_end", "sql_latitude", "sql_longitude", "sql_start", "start_location_field", "string_datatype", "style", "suggest_dimension", "suggest_explore", "suggest_persist_for", "suggestable", "suggestions", "tags", "tiers", "timeframes", "type", "units", "value_format", "value_format_name", "view_label" };

pub fn isValidKey(needle: []const u8, haystack: [][]const u8) bool {
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
    // _ = items;
    // const count = items.len;
    // var i: i8 = 1;
    print("[", .{});
    for (items) |item| {
        print("###type: {any}", .{@TypeOf(item)});
        // const dereferenced = item.*;
        // print("##{s}\n", .{dereferenced.label});
        // try item.stringify();
        // if (i < count) {
        //     try printComma();
        // }
        // i += 1;
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

pub fn trimString(chars: []const u8) []const u8 {
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
    arena: *std.heap.ArenaAllocator,
    allocator: Allocator,
    filename: []const u8,
    includes: [][]const u8,
    views: []*View,
    explores: []Explore,
    objectIndex: usize,
    views_as_string: []const u8,

    pub fn init(parent_allocator: Allocator, filename: []const u8) !Lkml {
        var arena = try parent_allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(parent_allocator);
        const allocator = arena.allocator();

        return Lkml{
            .arena = arena,
            .allocator = allocator,
            .filename = filename,
            .includes = try allocator.alloc([]const u8, 0),
            .views = try allocator.alloc(*View, 0),
            .explores = try allocator.alloc(Explore, 0),
            .objectIndex = 0,
            .views_as_string = "",
        };
    }

    pub fn stringify(self: *Lkml) !void {
        try printComma();
        print("\"filename\": \"{s}\", ", .{self.filename});
        print("\"includes\": ", .{});
        try printStrings(self.includes);
        try printComma();
        print("\"views\": ", .{});
        print("{s}", .{self.views_as_string});
    }

    pub fn addInclude(self: *Lkml, include: []const u8) !void {
        self.includes = try self.add([][]const u8, []const u8, self.includes, include);
    }

    pub fn addView(self: *Lkml, view: *View) !void {
        self.views = try self.add([]*View, *View, self.views, view);
    }

    pub fn addExplore(self: *Lkml, explore: Explore) !void {
        self.explores = try self.add([]Explore, Explore, self.explores, explore);
    }

    pub fn addItem(self: *Lkml, depth: usize, key: []const u8, val: []const u8, valType: []const u8) !void {
        // print("{any}, {s}, {s}, {s}", .{depth, key, val, valType});
        var objectType: []const u8 = undefined;
        var objectField: []const u8 = undefined;
        var param: []const u8 = undefined;
        var keySplit = std.mem.splitSequence(u8, key, ".");
        if (depth == 0) {
            if (eq(key, "include")) {
                try self.addInclude(val);
            }
            if (eq(key, "view")) {
                var view = try View.init(self.allocator, val);
                try view.initFieldMap();
                try self.addView(&view);
                self.objectIndex = self.views.len - 1;
            }
            if (eq(key, "explore")) {
                const explore = try Explore.init(self.allocator, val);
                try self.addExplore(explore);
                self.objectIndex = self.explores.len - 1;
            }
            return;
        }
        if (keySplit.next()) |res| {
            objectType = res;
        }
        if (keySplit.next()) |res| {
            objectField = res;
        }
        if (keySplit.next()) |res| {
            param = res;
        }

        const isView = eq(objectType, "view");
        const isExplore = eq(objectType, "explore");

        if (depth == 1 and isView) {
            const object = self.views[self.objectIndex];
            var field = try Field.init(self.allocator, val);
            try field.initFieldMap();
            try object.update(objectField, val, valType, field);
            // end of object
            if (objectField[0] == 48) {
                const object_as_string = try object.stringify();
                self.views_as_string = try std.fmt.allocPrint(self.allocator, "{s},{s}", .{ self.views_as_string, object_as_string });
            }
            return;
        }

        if (depth == 1 and isExplore and eq(objectField, "name")) {
            self.explores[self.objectIndex].name = val;
            return;
        }

        if (depth == 2) {
            const object = self.views[self.objectIndex];
            var field = object.dimensions[object.dimensions.len - 1];
            try field.update(trimString(param), trimString(val), valType);
            // Update field
            if (param[0] == 48) {
                const field_as_string = try field.stringify();
                object.dimensions_as_string = try std.fmt.allocPrint(self.allocator, "{s},{s}", .{ object.dimensions_as_string, field_as_string });
                // print("$$${s}\n", .{object.dimensions_as_string});
            }
            param = "";
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
    arena: *std.heap.ArenaAllocator,
    allocator: Allocator,
    map_strings: std.StringHashMap(*[]const u8),
    map_string_lists: std.StringHashMap(*[][]const u8),
    map_fields: std.StringHashMap(*[]Field),
    map_derived_table: std.StringHashMap(*DerivedTable),
    name: []const u8,
    label: []const u8,
    extension: []const u8,
    sql_table_name: []const u8,
    drill_fields: []const u8,
    suggestions: []const u8,
    fields_hidden_by_default: []const u8,
    extends: [][]const u8,
    required_access_grants: [][]const u8,
    dimensions: []Field,
    dimension_groups: []Field,
    filters: []Field,
    parameters: []Field,
    measures: []Field,
    dimensions_as_string: []const u8,
    dimension_groups_as_string: []const u8,
    filters_as_string: []const u8,
    parameters_as_string: []const u8,
    measures_as_string: []const u8,
    derived_table: DerivedTable,

    pub fn init(parent_allocator: Allocator, name: []const u8) !View {
        var arena = try parent_allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(parent_allocator);
        const allocator = arena.allocator();
        defer arena.deinit();

        return View{
            .arena = arena,
            .allocator = allocator,
            .map_strings = std.StringHashMap(*[]const u8).init(allocator),
            .map_string_lists = std.StringHashMap(*[][]const u8).init(allocator),
            .map_fields = std.StringHashMap(*[]Field).init(allocator),
            .map_derived_table = std.StringHashMap(*DerivedTable).init(allocator),
            .name = name,
            .label = "",
            .extension = "",
            .sql_table_name = "",
            .drill_fields = "",
            .suggestions = "",
            .fields_hidden_by_default = "",
            .extends = try allocator.alloc([]const u8, 0),
            .required_access_grants = try allocator.alloc([]const u8, 0),
            .dimensions = try allocator.alloc(Field, 0),
            .dimension_groups = try allocator.alloc(Field, 0),
            .filters = try allocator.alloc(Field, 0),
            .parameters = try allocator.alloc(Field, 0),
            .measures = try allocator.alloc(Field, 0),
            .dimensions_as_string = "",
            .dimension_groups_as_string = "",
            .filters_as_string = "",
            .parameters_as_string = "",
            .measures_as_string = "",
            .derived_table = try DerivedTable.init(allocator),
        };
    }

    pub fn initFieldMap(self: *View) !void {
        // strings
        try self.map_strings.put("name", &self.name);
        try self.map_strings.put("label", &self.label);
        try self.map_strings.put("extension", &self.extension);
        try self.map_strings.put("sql_table_name", &self.sql_table_name);
        try self.map_strings.put("drill_fields", &self.drill_fields);
        try self.map_strings.put("suggestions", &self.suggestions);
        try self.map_strings.put("fields_hidden_by_default", &self.fields_hidden_by_default);

        // string list
        try self.map_string_lists.put("extends", &self.extends);
        try self.map_string_lists.put("required_access_grants", &self.required_access_grants);

        // field list
        try self.map_fields.put("dimension", &self.dimensions);
        try self.map_fields.put("dimension_group", &self.dimension_groups);
        try self.map_fields.put("filter", &self.filters);
        try self.map_fields.put("parameter", &self.parameters);
        try self.map_fields.put("measure", &self.measures);

        // custom
        try self.map_derived_table.put("derived_table", &self.derived_table);
    }

    pub fn asString(self: *View, T: type, field: T) ![]const u8 {
        if (T == []const u8) {
            return field;
        }
        if (T == [][]const u8) {
            var result: []const u8 = "";
            var count: u32 = 0;
            for (field) |item| {
                if (count == 0) {
                    result = try std.fmt.allocPrint(self.allocator, "\"{s}\"", .{item});
                } else {
                    result = try std.fmt.allocPrint(self.allocator, "{s},\"{s}\"", .{ result, item });
                }
                count += 1;
            }
            return result;
        }
        if (T == []Field) {
            var result: []const u8 = "";
            var count: u32 = 0;
            for (field) |item| {
                if (count == 0) {
                    result = try std.fmt.allocPrint(self.allocator, "\"{s}\"", .{try item.stringify()});
                } else {
                    result = try std.fmt.allocPrint(self.allocator, "{s},\"{s}\"", .{ result, try item.stringify() });
                }
                count += 1;
            }
            return result;
        }
        return "123";
    }

    pub fn stringify(self: *View) ![]const u8 {
        const self_as_string: []const u8 = try std.fmt.allocPrint(self.allocator, "{{" ++
            // "\"name\": \"{s}\"," ++
            // "\"label\": \"{s}\"," ++
            // "\"extension\": \"{s}\"," ++
            // "\"sql_table_name\": \"{s}\"," ++
            // "\"drill_fields\": \"{s}\"," ++
            // "\"suggestions\": \"{s}\"," ++
            // "\"fields_hidden_by_default\": \"{s}\"," ++
            // "\"extends\": [{s}]," ++
            // "\"required_access_grants\": [{s}]," ++
            "\"dimensions\": [{s}]," ++
            // "\"dimension_groups\": [{s}]," ++
            // "\"filters\": [{s}]," ++
            // "\"parameters\": [{s}]," ++
            // "\"measures\": [{s}]," ++
            // "\"derived_table\": [{s}]," ++
            "}}", .{
            // try self.asString([]const u8, self.name),
            // try self.asString([]const u8, self.label),
            // try self.asString([]const u8, self.extension),
            // try self.asString([]const u8, self.sql_table_name),
            // try self.asString([]const u8, self.drill_fields),
            // try self.asString([]const u8, self.suggestions),
            // try self.asString([]const u8, self.fields_hidden_by_default),
            // try self.asString([][]const u8, self.extends),
            // try self.asString([][]const u8, self.required_access_grants),
            // try self.asString([]Field, self.dimensions),
            try self.asString([]const u8, self.dimensions_as_string),
            // try self.asString([]Field, self.dimension_groups),
            // try self.asString([]Field, self.filters),
            // try self.asString([]Field, self.parameters),
            // try self.asString([]Field, self.measures),
            // try self.asString(DerivedTable, self.derived_table),
        });
        return self_as_string;
    }

    pub fn update(self: *View, key: []const u8, val: []const u8, valType: []const u8, field: Field) !void {
        if (self.map_strings.contains(key)) {
            const field_pointer = self.map_strings.get(key) orelse return error.UnknownField;
            field_pointer.* = val;
            return;
        }
        if (self.map_string_lists.contains(key)) {
            const field_pointer = self.map_string_lists.get(key) orelse return error.UnknownField;
            var valSplit = std.mem.splitSequence(u8, val, "|,|");
            while (valSplit.next()) |listItem| {
                field_pointer.* = try self.add(@TypeOf(field_pointer.*), []const u8, field_pointer.*, trimString(listItem));
            }
            return;
        }
        if (self.map_fields.contains(key) and eq(key, "dimension")) {
            const field_pointer = self.map_fields.get(key) orelse return error.UnknownField;
            field_pointer.* = try self.add(@TypeOf(field_pointer.*), Field, field_pointer.*, field);
            // _ = field;
            _ = valType;
        }
    }

    fn add(self: *View, srcType: type, itemType: type, src: srcType, item: itemType) !srcType {
        const count = src.len + 1;
        var more = try self.allocator.alloc(itemType, count);
        std.mem.copyForwards(itemType, more[0..count], src);
        more[src.len] = item;
        self.allocator.free(src);
        return more;
    }

    pub fn deinit(self: *View, parent_allocator: Allocator) !void {
        self.allocator.free(self.map_string_lists);
        self.allocator.free(self.map_fields);
        self.allocator.free(self.map_strings);
        self.allocator.free(self.map_derived_table);
        self.arena.deinit();
        parent_allocator.destroy(self.arena);
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
    map_strings: std.StringHashMap(*[]const u8),
    name: []const u8,
    action: []const u8,
    alias: []const u8,
    allow_approximate_optimization: []const u8,
    allow_fill: []const u8,
    allowed_value: []const u8,
    alpha_sort: []const u8,
    approximate: []const u8,
    approximate_threshold: []const u8,
    bypass_suggest_restrictions: []const u8,
    can_filter: []const u8,
    case: []const u8,
    case_sensitive: []const u8,
    convert_tz: []const u8,
    datatype: []const u8,
    default_value: []const u8,
    description: []const u8,
    direction: []const u8,
    drill_fields: []const u8,
    end_location_field: []const u8,
    fanout_on: []const u8,
    fields: []const u8,
    filters: []const u8,
    full_suggestions: []const u8,
    group_item_label: []const u8,
    group_label: []const u8,
    hidden: []const u8,
    html: []const u8,
    intervals: []const u8,
    label: []const u8,
    label_from_parameter: []const u8,
    link: []const u8,
    list_field: []const u8,
    map_layer_name: []const u8,
    order_by_field: []const u8,
    percentile: []const u8,
    precision: []const u8,
    primary_key: []const u8,
    required_access_grants: []const u8,
    required_fields: []const u8,
    skip_drill_filter: []const u8,
    sql: []const u8,
    sql_distinct_key: []const u8,
    sql_end: []const u8,
    sql_latitude: []const u8,
    sql_longitude: []const u8,
    sql_start: []const u8,
    start_location_field: []const u8,
    string_datatype: []const u8,
    style: []const u8,
    suggest_dimension: []const u8,
    suggest_explore: []const u8,
    suggest_persist_for: []const u8,
    suggestable: []const u8,
    suggestions: []const u8,
    tags: []const u8,
    tiers: []const u8,
    timeframes: []const u8,
    type_name: []const u8,
    units: []const u8,
    value_format: []const u8,
    value_format_name: []const u8,
    view_label: []const u8,

    pub fn init(allocator: Allocator, name: []const u8) !Field {
        return .{
            .allocator = allocator,
            .map_strings = std.StringHashMap(*[]const u8).init(allocator),
            .name = name,
            .action = "",
            .alias = "",
            .allow_approximate_optimization = "",
            .allow_fill = "",
            .allowed_value = "",
            .alpha_sort = "",
            .approximate = "",
            .approximate_threshold = "",
            .bypass_suggest_restrictions = "",
            .can_filter = "",
            .case = "",
            .case_sensitive = "",
            .convert_tz = "",
            .datatype = "",
            .default_value = "",
            .description = "",
            .direction = "",
            .drill_fields = "",
            .end_location_field = "",
            .fanout_on = "",
            .fields = "",
            .filters = "",
            .full_suggestions = "",
            .group_item_label = "",
            .group_label = "",
            .hidden = "",
            .html = "",
            .intervals = "",
            .label = "",
            .label_from_parameter = "",
            .link = "",
            .list_field = "",
            .map_layer_name = "",
            .order_by_field = "",
            .percentile = "",
            .precision = "",
            .primary_key = "",
            .required_access_grants = "",
            .required_fields = "",
            .skip_drill_filter = "",
            .sql = "",
            .sql_distinct_key = "",
            .sql_end = "",
            .sql_latitude = "",
            .sql_longitude = "",
            .sql_start = "",
            .start_location_field = "",
            .string_datatype = "",
            .style = "",
            .suggest_dimension = "",
            .suggest_explore = "",
            .suggest_persist_for = "",
            .suggestable = "",
            .suggestions = "",
            .tags = "",
            .tiers = "",
            .timeframes = "",
            .type_name = "",
            .units = "",
            .value_format = "",
            .value_format_name = "",
            .view_label = "",
        };
    }

    pub fn initFieldMap(self: *Field) !void {
        // try self.map_strings.put("action", &self.action);
        // try self.map_strings.put("alias", &self.alias);
        // try self.map_strings.put("allow_approximate_optimization", &self.allow_approximate_optimization);
        // try self.map_strings.put("allow_fill", &self.allow_fill);
        // try self.map_strings.put("allowed_value", &self.allowed_value);
        // try self.map_strings.put("alpha_sort", &self.alpha_sort);
        // try self.map_strings.put("approximate", &self.approximate);
        // try self.map_strings.put("approximate_threshold", &self.approximate_threshold);
        // try self.map_strings.put("bypass_suggest_restrictions", &self.bypass_suggest_restrictions);
        // try self.map_strings.put("can_filter", &self.can_filter);
        // try self.map_strings.put("case", &self.case);
        // try self.map_strings.put("case_sensitive", &self.case_sensitive);
        // try self.map_strings.put("convert_tz", &self.convert_tz);
        // try self.map_strings.put("datatype", &self.datatype);
        // try self.map_strings.put("default_value", &self.default_value);
        // try self.map_strings.put("description", &self.description);
        // try self.map_strings.put("direction", &self.direction);
        // try self.map_strings.put("drill_fields", &self.drill_fields);
        // try self.map_strings.put("end_location_field", &self.end_location_field);
        // try self.map_strings.put("fanout_on", &self.fanout_on);
        // try self.map_strings.put("fields", &self.fields);
        // try self.map_strings.put("filters", &self.filters);
        // try self.map_strings.put("full_suggestions", &self.full_suggestions);
        // try self.map_strings.put("group_item_label", &self.group_item_label);
        // try self.map_strings.put("group_label", &self.group_label);
        // try self.map_strings.put("hidden", &self.hidden);
        // try self.map_strings.put("html", &self.html);
        // try self.map_strings.put("intervals", &self.intervals);
        // try self.map_strings.put("label", &self.label);
        // try self.map_strings.put("label_from_parameter", &self.label_from_parameter);
        // try self.map_strings.put("link", &self.link);
        // try self.map_strings.put("list_field", &self.list_field);
        // try self.map_strings.put("map_layer_name", &self.map_layer_name);
        // try self.map_strings.put("order_by_field", &self.order_by_field);
        // try self.map_strings.put("percentile", &self.percentile);
        // try self.map_strings.put("precision", &self.precision);
        // try self.map_strings.put("primary_key", &self.primary_key);
        // try self.map_strings.put("required_access_grants", &self.required_access_grants);
        // try self.map_strings.put("required_fields", &self.required_fields);
        // try self.map_strings.put("skip_drill_filter", &self.skip_drill_filter);
        try self.map_strings.put("sql", &self.sql);
        // try self.map_strings.put("sql_distinct_key", &self.sql_distinct_key);
        // try self.map_strings.put("sql_end", &self.sql_end);
        // try self.map_strings.put("sql_latitude", &self.sql_latitude);
        // try self.map_strings.put("sql_longitude", &self.sql_longitude);
        // try self.map_strings.put("sql_start", &self.sql_start);
        // try self.map_strings.put("start_location_field", &self.start_location_field);
        // try self.map_strings.put("string_datatype", &self.string_datatype);
        // try self.map_strings.put("style", &self.style);
        // try self.map_strings.put("suggest_dimension", &self.suggest_dimension);
        // try self.map_strings.put("suggest_explore", &self.suggest_explore);
        // try self.map_strings.put("suggest_persist_for", &self.suggest_persist_for);
        // try self.map_strings.put("suggestable", &self.suggestable);
        // try self.map_strings.put("suggestions", &self.suggestions);
        // try self.map_strings.put("tags", &self.tags);
        // try self.map_strings.put("tiers", &self.tiers);
        // try self.map_strings.put("timeframes", &self.timeframes);
        // try self.map_strings.put("type", &self.type_name);
        // try self.map_strings.put("units", &self.units);
        // try self.map_strings.put("value_format", &self.value_format);
        // try self.map_strings.put("value_format_name", &self.value_format_name);
        // try self.map_strings.put("view_label", &self.view_label);
    }

    pub fn update(self: *Field, key: []const u8, val: []const u8, valType: []const u8) !void {
        print("key:{s}, val:{s}\n", .{key, val});
        if (self.map_strings.contains(key)) {
            print("name:{s}\n", .{self.name});
            const field_pointer = self.map_strings.get(key) orelse return error.UnknownField;
            field_pointer.* = val;
            print("self.sql={s}\n", .{self.sql});
            return;
        }
        _ = valType;
    }

    pub fn stringify(self: Field) ![]const u8 {
        const self_as_string: []const u8 = try std.fmt.allocPrint(self.allocator, "{{" ++
            "\"name\": \"{s}\"," ++
            "\"sql\": \"{s}\"," ++
            "}}", .{
            self.name,
            self.sql,
        });
        return self_as_string;
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

    pub fn initFieldMap(self: *View) !void {
        // strings
        try self.map_strings.put("name", &self.name);
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
                newKey = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ newKey, keyPart });
            }
            depthCounter += 1;
        }
        newKey = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ newKey, itemKey });
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
            self.removeOutputLastChars(1);
            printBuff = try std.fmt.allocPrint(self.allocator, "|,|", .{});
            try self.addOutput(printBuff[0..], 0);
        }
        // value close
        if (self.isValue and ((!self.isSql and self.valueTerminatorChar == char) or (self.chars.len > 1 and self.isSql and self.valueTerminatorChar == char and self.chars[self.chars.len - 2] == self.valueTerminatorChar) or (self.chars.len > 1 and self.isNonQuoted and (self.valueTerminatorChar == char or char == 10)))) {
            if (char == 32 or char == 10) {
                self.removeOutputLastChars(1);
            }
            // brackets close
            if (self.isBrackets) {
                self.isBrackets = false;
                self.removeOutputLastChars(1);
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
                const key: []const u8 = "0";
                try self.updateKey(key);
                printBuff = try std.fmt.allocPrint(self.allocator, "\n<{s}>##!util", .{self.key});
                try self.addOutput(printBuff[0..], 0);

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
                key = key[0 .. key.len - 1];
                try self.updateKey(key);
                // self.key = try std.fmt.allocPrint(self.allocator, "{any}.{s}", .{self.depth,key});

                printBuff = try std.fmt.allocPrint(self.allocator, "\n<{s}>", .{self.key});
                try self.addOutput(printBuff[0..], key.len + 1);
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
                self.removeOutputLastChars(1);
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

pub const KeyValue = struct {
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
    var mainSplit = std.mem.splitSequence(u8, parsed, "<.");

    while (mainSplit.next()) |item| {
        var itemSplit = std.mem.splitSequence(u8, item, ">");
        if (itemSplit.next()) |key| {
            const depth = std.mem.count(u8, key, ".");
            if (itemSplit.next()) |valWrapper| {
                var valSplit = std.mem.splitSequence(u8, valWrapper, "#!");
                if (valSplit.next()) |val| {
                    if (valSplit.next()) |valType| {
                        try lkml.addItem(depth, key, val, valType);
                    }
                }
            }
        }
    }

    try lkml.stringify();
}
