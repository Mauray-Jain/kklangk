const std = @import("std");

pub const Ops = enum {
    PUSH,
    DUP,
    COPYNTH,
    SWAP,
    POP,
    POPN,

    ADD,
    SUB,
    MULT,
    DIV,
    MOD,

    HEAPSTR,
    HEAPRET,

    MARK,
    CALL,
    JMP,
    JMPIF0,
    JMPIFNEG,
    RETURN,
    EXIT,

    OUTCHAR,
    OUTNUM,
    INCHAR,
    INNUM,

    pub inline fn disas(val: @This()) [:0]const u8 {
        return @tagName(val);
    }
};
