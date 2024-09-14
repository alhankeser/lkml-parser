const std = @import("std");
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const print = std.debug.print;


pub const Reader = struct {
    allocator: Allocator,
    lkml: []u8,
    i: u64,

    pub fn init(allocator: Allocator, lkml: []u8) Reader {
        return Reader{
            .allocator = allocator,
            .lkml = lkml,
            .i = 0,
        };
    }

    pub fn next(self: *Reader) u8 {
        const next_i = self.i + 1;
        if (next_i < self.lkml.len) {
            self.i += 1;
        }
        
    }
};


pub const Parser = struct {



};

pub fn run(allocator: Allocator, lkml: []u8) []u8 {
    const reader = Reader.init(allocator, lkml);
    _ = reader;
    return lkml;
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

    _ = run(allocator, readBuf);
   

    // Print out
    // const output = try parser.getOutput();
    // _ = try stdout.write(output);
}
