const std = @import("std");
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const print = std.debug.print;

const Token = @import("token.zig").Token;

pub const Parser = struct {
    
};