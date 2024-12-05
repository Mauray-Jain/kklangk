const std = @import("std");

pub const Chunk = []const Ops;

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
