const std = @import("std");

pub const Chunk = struct {
    ops: []const Ops,
    lines: []const LineInfo,

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
};

pub const LineInfo = struct {
    linenum: usize,
    offset: usize,
};

pub const Ops = union(enum) {
    PUSH: isize,
    DUP,
    COPYNTH: isize,
    SWAP,
    POP,
    // POPN: isize,

    ADD,
    SUB,
    MULT,
    DIV,
    MOD,

    HEAPSTR,
    HEAPRET,

    MARK: isize,
    CALL: isize,
    JMP: isize,
    JMPIF0: isize,
    JMPIFNEG: isize,
    RETURN,
    EXIT,

    OUTCHAR,
    OUTNUM,
    INCHAR,
    INNUM,

    pub fn disas(val: @This()) void {
        const tag = @tagName(val);
        inline for (std.meta.fields(@This())) |f| {
            if (std.mem.eql(u8, f.name, tag)) {
                std.debug.print("{} {s}\n", .{ @field(val, f.name), f.name });
            }
        }
    }
};
//
// test "tt" {
//     var t = Ops{ .JMP = 10 };
//     _ = &t;
//     t.disas();
//     const v = Ops{ .EXIT = void{} };
//     v.disas();
// }
