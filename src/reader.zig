pub const Reader = struct {
    lkml: []u8,
    i: u32,
    line: u32,
    start: u32,

    pub fn init(lkml: []u8) Reader {
        return Reader{
            .lkml = lkml,
            .i = 0,
            .line = 1,
            .start = 0,
        };
    }

    pub fn next(self: *Reader) u8 {
        self.i += 1;
        return self.curr();
    }

    pub fn finished(self: *Reader) bool {
        return (self.i + 1) >= self.lkml.len;
    }

    pub fn curr(self: *Reader) u8 {
        const result = self.lkml[self.i];
        if (result == 10) {
            self.new_line();
        }
        return result;
    }

    fn curr_line(self: *Reader) u32 {
        return self.line;
    }

    fn new_line(self: *Reader) void {
        self.line += 1;
    }

    pub fn reset_range(self: *Reader) void {
        self.start = self.i;
    }

    pub fn range(self: *Reader) [2]u32 {
        var i = self.i;
        if (self.start == i) {
            i += 1;
        }
        return [2]u32{ self.start, i };
    }

    pub fn chars(self: *Reader) []u8 {
        if (self.start <= self.i) {
            return self.lkml[self.start..self.i];
        }
        return &[_]u8{};
    }
};
