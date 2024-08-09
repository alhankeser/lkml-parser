const std = @import("std");
const stdout = std.io.getStdOut().writer();

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

    var it = std.mem.window(u8, readBuf, 1, 1);
    // var isComment = false;
    var quotesOpen = false;
    var quoteChar: []const u8 = "\"";
    var isKey = true;
    while (it.next()) |char| {
        std.debug.print("{s}", .{char});
        if (std.mem.eql(u8, char, "'") or std.mem.eql(u8, char, "\"")) {
            if (!quotesOpen) {
                quotesOpen = true;
                quoteChar = char;
                std.debug.print("{s}", .{"<quote open>"});
                continue;
            }
            if (quotesOpen and std.mem.eql(u8, char, quoteChar)) {
                quotesOpen = false;
                std.debug.print("{s}", .{"<quote close>"});
                continue;
            }
        }
        if (std.mem.eql(u8, char, "\n") and !quotesOpen) {
            isKey = true;
        }
    }
}
