const std = @import("std");
const Tokenizer = @import("Tokenizer.zig");
const Token = @import("Tokenizer.zig").Token;
const Chunk = @import("Chunk.zig");
const Ops = @import("Chunk.zig").Ops;
const LineInfo = @import("Chunk.zig").LineInfo;

tokenizer: Tokenizer,
ops: std.ArrayList(Ops),
line_info: std.ArrayList(LineInfo),
line: usize,
state: State,
unscanned_token: Token,
any_unscanned: bool,

const State = enum {
    number,
    stack,
    heap,
    arithmetic,
    flow,
    io,
    command,
};

pub const ParseErrors = error{
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
        .line = 0,
        .state = .command,
        .unscanned_token = undefined,
        .any_unscanned = false,
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
    defer self.state = .command;

    while (true) {
        const token = blk: {
            if (self.any_unscanned) {
                self.any_unscanned = false;
                break :blk self.unscanned_token;
            }
            break :blk self.tokenizer.scanToken();
        };

        // token.disas();

        if (token == .EOF and self.state == .command) break; // checking state of command so as to handle the case where the number is the last token

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
                    .ASA => |i| return .{ .op = Ops{ .DUP = void{} }, .line = i },
                    .SAADE => |i| {
                        self.state = .number;
                        op = Ops{ .COPYNTH = undefined };
                        line = i;
                    },
                    .YEH => |i| return .{ .op = Ops{ .SWAP = void{} }, .line = i },
                    .TUH => |i| return .{ .op = Ops{ .POP = void{} }, .line = i },
                    else => return ParseErrors.InvalidOperationOnStack,
                }
            },

            .arithmetic => {
                switch (token) {
                    .YEH => |i| return .{ .op = Ops{ .SUB = void{} }, .line = i },
                    .TUH => |i| return .{ .op = Ops{ .ADD = void{} }, .line = i },
                    .ASA => |i| return .{ .op = Ops{ .MULT = void{} }, .line = i },
                    .CHUSS => |i| return .{ .op = Ops{ .DIV = void{} }, .line = i },
                    .HORR => |i| return .{ .op = Ops{ .MOD = void{} }, .line = i },
                    .GOIZ => |i| return .{ .op = Ops{ .XOR = void{} }, .line = i },
                    else => return ParseErrors.InvalidArithmeticOperation,
                }
            },

            .heap => {
                switch (token) {
                    .YEH => |i| return .{ .op = Ops{ .HEAPSTR = void{} }, .line = i },
                    .TUH => |i| return .{ .op = Ops{ .HEAPRET = void{} }, .line = i },
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
                    .YEH => |i| return .{ .op = Ops{ .RETURN = void{} }, .line = i },
                    .TUH => |i| return .{ .op = Ops{ .EXIT = void{} }, .line = i },
                    else => return ParseErrors.InvalidControlFlowOperation,
                }
            },

            .io => {
                switch (token) {
                    .YEH => |i| return .{ .op = Ops{ .OUTCHAR = void{} }, .line = i },
                    .TUH => |i| return .{ .op = Ops{ .INCHAR = void{} }, .line = i },
                    .ASA => |i| return .{ .op = Ops{ .OUTNUM = void{} }, .line = i },
                    .CHUSS => |i| return .{ .op = Ops{ .INNUM = void{} }, .line = i },
                    else => return ParseErrors.InvalidIOOperation,
                }
            },

            .number => {
                switch (token) {
                    .YEH => num <<= 1,
                    .TUH => num = (num << 1) + @as(i64, 1),
                    else => {
                        self.any_unscanned = true;
                        self.unscanned_token = token;
                        switch (op) {
                            else => |*v| {
                                const ptr: *i64 = @ptrCast(v);
                                ptr.* = num;
                            },
                        }
                        // std.debug.print("here\n", .{});
                        return .{ .op = op, .line = line };
                    },
                }
            },
        }
    }

    return ParseErrors.EndOfFile;
}

pub fn populateBytecode(self: *Self) !void {
    var offset: usize = 0;

    while (true) {
        const op_line_pair = self.emitBytecode() catch |err| switch (err) {
            ParseErrors.EndOfFile => break,
            else => return err,
        };

        if (self.line != op_line_pair.line) {
            self.line = op_line_pair.line;
            try self.line_info.append(.{ .offset = offset, .linenum = self.line });
        }

        try self.ops.append(op_line_pair.op);

        offset += 1;
    }
}

pub fn makeChunk(self: *Self) !Chunk {
    return Chunk{
        .ops = try self.ops.toOwnedSlice(),
        .lines = try self.line_info.toOwnedSlice(),
    };
}

test "parser" {
    const src =
        \\asa chuss yeh tuh yeh tuh
        \\horr tuh goiz yeh
        \\goiz yeh
    ;

    const a = std.testing.allocator;

    var parser: Self = Self.init(a, src);

    try parser.populateBytecode();
    const chunk = try parser.makeChunk();
    defer a.free(chunk.ops);
    defer a.free(chunk.lines);

    std.debug.print("{any}\n", .{chunk.ops});
    std.debug.print("{any}\n", .{chunk.lines});
}
