const std = @import("std");
const Tokenizer = @import("Tokenizer.zig");
const Token = @import("Tokenizer.zig").Token;
const Ops = @import("Chunk.zig").Ops;
const LineInfo = @import("Chunk.zig").LineInfo;

tokenizer: Tokenizer,
ops: std.ArrayList(Ops),
line_info: std.ArrayList(LineInfo),
state: State,

const State = enum {
    number,
    stack,
    heap,
    arithmetic,
    flow,
    io,
    command,
};

const ParseErrors = error{
    EndOfFile,
    InvalidCommand,
    InvalidOperationOnStack,
    InvalidArithmeticOperation,
    InvalidOperationOnHeap,
    InvalidControlFlowOperation,
    InvalidIOOperation,
};

const Self = @This();

pub fn init(allocator: std.mem.Allocator, src: []const u8) Self {
    return Self{
        .tokenizer = Tokenizer.init(src),
        .ops = std.ArrayList(Ops).init(allocator),
        .line_info = std.ArrayList(LineInfo).init(allocator),
        .state = .command,
    };
}

pub fn deinit(self: *Self) void {
    self.ops.deinit();
    self.line_info.deinit();
}

fn emitBytecode(self: *Self) ParseErrors!struct { op: Ops, line: usize } {
    // For bytecode instructions that have a number attached too eg: PUSH
    var op: Ops = undefined;
    var num: i64 = 0;
    var line: usize = undefined;

    while (true) {
        const token = self.tokenizer.scanToken();
        if (token == .EOF) break;

        switch (self.state) {
            .command => {
                switch (token) {
                    .ASA => self.state = .stack,
                    .HORR => self.state = .arithmetic,
                    .SAADE => self.state = .heap,
                    .BELLE => self.state = .flow,
                    .GOIZ => self.state = .io,
                    else => return ParseErrors.InvalidCommand,
                }
            },

            .stack => {
                switch (token) {
                    .CHUSS => |i| {
                        self.state = .number;
                        op = Ops{ .PUSH = undefined };
                        line = i;
                    },
                    .ASA => |i| {
                        self.state = .command;
                        return .{ .op = Ops{ .DUP = void{} }, .line = i };
                    },
                    .SAADE => |i| {
                        self.state = .number;
                        op = Ops{ .COPYNTH = undefined };
                        line = i;
                    },
                    .YEH => |i| {
                        self.state = .command;
                        return .{ .op = Ops{ .SWAP = void{} }, .line = i };
                    },
                    .TUH => |i| {
                        self.state = .command;
                        return .{ .op = Ops{ .POP = void{} }, .line = i };
                    },
                    else => return ParseErrors.InvalidOperationOnStack,
                }
            },

            .arithmetic => {
                switch (token) {
                    .YEH => |i| {
                        self.state = .command;
                        return .{ .op = Ops{ .SUB = void{} }, .line = i };
                    },
                    .TUH => |i| {
                        self.state = .command;
                        return .{ .op = Ops{ .ADD = void{} }, .line = i };
                    },
                    .ASA => |i| {
                        self.state = .command;
                        return .{ .op = Ops{ .MULT = void{} }, .line = i };
                    },
                    .CHUSS => |i| {
                        self.state = .command;
                        return .{ .op = Ops{ .DIV = void{} }, .line = i };
                    },
                    .HORR => |i| {
                        self.state = .command;
                        return .{ .op = Ops{ .MOD = void{} }, .line = i };
                    },
                    else => return ParseErrors.InvalidArithmeticOperation,
                }
            },

            .heap => {
                switch (token) {
                    .YEH => |i| {
                        self.state = .command;
                        return .{ .op = Ops{ .HEAPSTR = void{} }, .line = i };
                    },
                    .TUH => |i| {
                        self.state = .command;
                        return .{ .op = Ops{ .HEAPRET = void{} }, .line = i };
                    },
                    else => return ParseErrors.InvalidOperationOnHeap,
                }
            },

            .flow => {
                switch (token) {
                    .ASA => |i| {
                        self.state = .number;
                        op = Ops{ .MARK = undefined };
                        line = i;
                    },
                    .CHUSS => |i| {
                        self.state = .number;
                        op = Ops{ .CALL = undefined };
                        line = i;
                    },
                    .HORR => |i| {
                        self.state = .number;
                        op = Ops{ .JMP = undefined };
                        line = i;
                    },
                    .GOIZ => |i| {
                        self.state = .number;
                        op = Ops{ .JMPIF0 = undefined };
                        line = i;
                    },
                    .SAADE => |i| {
                        self.state = .number;
                        op = Ops{ .JMPIFNEG = undefined };
                        line = i;
                    },
                    .YEH => |i| {
                        self.state = .command;
                        return .{ .op = Ops{ .RETURN = void{} }, .line = i };
                    },
                    .TUH => |i| {
                        self.state = .command;
                        return .{ .op = Ops{ .EXIT = void{} }, .line = i };
                    },
                    else => return ParseErrors.InvalidControlFlowOperation,
                }
            },

            .io => {
                switch (token) {
                    .YEH => |i| {
                        self.state = .command;
                        return .{ .op = Ops{ .OUTCHAR = void{} }, .line = i };
                    },
                    .TUH => |i| {
                        self.state = .command;
                        return .{ .op = Ops{ .INCHAR = void{} }, .line = i };
                    },
                    .ASA => |i| {
                        self.state = .command;
                        return .{ .op = Ops{ .OUTNUM = void{} }, .line = i };
                    },
                    .CHUSS => |i| {
                        self.state = .command;
                        return .{ .op = Ops{ .INNUM = void{} }, .line = i };
                    },
                    else => return ParseErrors.InvalidIOOperation,
                }
            },

            .number => {
                switch (token) {
                    .YEH => num = @shlExact(num, @as(u1, 1)),
                    .TUH => num = @shlExact(num, @as(u1, 1)) | @as(i64, 1),
                    else => {
                        self.state = .command;
                        switch (op) {
                            else => |*val| val.* = num,
                        }
                        return .{
                            .op = op,
                            .line = line,
                        };
                    },
                }
            },
        }
    }

    return ParseErrors.EndOfFile;
}

test "emitBytecode" {}
