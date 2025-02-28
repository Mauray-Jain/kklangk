const std = @import("std");

ops: []const Ops,
lines: []const LineInfo,

pub const LineInfo = struct {
    linenum: usize,
    offset: usize,
};

pub fn getLine(self: *const @This(), idx: usize) usize {
    var start: usize = 0;
    var end: usize = self.lines.len;
    // std.debug.print("Got: {d}\n", .{idx});

    while (start < end) {
        const mid = (start + end) / 2;
        const lineinfo = self.lines[mid];
        if (idx < lineinfo.offset) {
            end = mid;
        } else if (mid == self.lines.len - 1 or idx < self.lines[mid + 1].offset) {
            return lineinfo.linenum;
        } else {
            start = mid + 1;
        }
    }
    return 0;
}

pub const Ops = union(enum) {
    PUSH: i64,
    DUP,
    COPYNTH: i64,
    SWAP,
    POP,
    // POPN: i64,

    ADD,
    SUB,
    MULT,
    DIV,
    MOD,

    HEAPSTR,
    HEAPRET,

    MARK: i64,
    CALL: i64,
    JMP: i64,
    JMPIF0: i64,
    JMPIFNEG: i64,
    RETURN,
    EXIT,

    OUTCHAR,
    OUTNUM,
    INCHAR,
    INNUM,

    pub fn disas(val: @This()) void {
        const tag = @tagName(val);
        inline for (std.meta.fields(@This())) |f| { // doing bcoz in @field the name shld be comptime known
            if (std.mem.eql(u8, f.name, tag)) {
                std.debug.print("{} {s}\n", .{ @field(val, f.name), f.name });
            }
        }
    }
};

// test "tt" {
//     var t = Ops{ .JMP = 10 };
//     _ = &t;
//     t.disas();
//     const v = Ops{ .EXIT = void{} };
//     v.disas();
// }
