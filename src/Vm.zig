const std = @import("std");
const Chunk = @import("Chunk.zig");
const Ops = @import("Chunk.zig").Ops;

const Self = @This();

const AllocError = std.mem.Allocator.Error;
pub const VMErrors = error{
    InsufficientElements,
    EmptyCallStack,
    InvalidLabel,
    NoSuchElement,
} || AllocError;

const HeapVal = struct {
    address: i64,
    val: i64,
};

const Label = struct {
    name: i64,
    pos: isize,
};

stack: std.ArrayList(i64),
heap: std.ArrayList(HeapVal),
labels: std.ArrayList(Label),
call_stack: std.ArrayList(i64),
chunk: Chunk,
ip: isize,

pub fn init(allocator: std.mem.Allocator, chunk: Chunk) Self {
    return Self{
        .stack = std.ArrayList(i64).init(allocator),
        .heap = std.ArrayList(HeapVal).init(allocator),
        .labels = std.ArrayList(Label).init(allocator),
        .call_stack = std.ArrayList(i64).init(allocator),
        .chunk = chunk,
        .ip = @as(isize, @intCast(chunk.ops.len)),
    };
}

pub fn deinit(self: *Self) void {
    self.stack.deinit();
    self.heap.deinit();
    self.labels.deinit();
    self.call_stack.deinit();
    self.ip = 0;
}

fn handleErr(self: *Self, err: anyerror) u8 {
    const line = self.chunk.getLine(@intCast(self.ip));
    const msg = switch (err) {
        VMErrors.OutOfMemory => "Peg Tim Cook",
        VMErrors.EmptyCallStack => "Chandigarh train missed",
        VMErrors.InvalidLabel => "Hey that label doesnt exist",
        VMErrors.NoSuchElement => "No such element on the heap",
        VMErrors.InsufficientElements => "Not enough elements on stack to do this",
        else => @errorName(err),
    };
    var stderr = std.io.getStdErr().writer();
    stderr.print("Line {d}:\n\t{s}: {s}\n", .{ line, @errorName(err), msg }) catch {};
    self.deinit();
    return 1;
    // std.process.exit(1);
}

pub fn run(self: *Self) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    // Storing all labels and finding label 16 (main)
    for (self.chunk.ops, 0..) |op, pos| {
        switch (op) {
            .MARK => {
                try self.mark(op.MARK, @intCast(pos));
                if (op.MARK == 16) {
                    self.ip = @intCast(pos);
                }
            },
            else => {},
        }
    }

    // Execing them
    while (self.ip < self.chunk.ops.len) : (self.ip += 1) {
        // std.debug.print("{any}\n", .{self.stack.items});
        const op = self.chunk.ops[@intCast(self.ip)];
        try self.execInstruction(op, stdout, stdin);
    }
}

fn execInstruction(self: *Self, op: Ops, stdout: std.fs.File.Writer, stdin: std.fs.File.Reader) anyerror!void {
    switch (op) {
        .EXIT => self.ip = @as(isize, @intCast(self.chunk.ops.len)),
        .PUSH => try self.push(op.PUSH),
        .DUP => try self.dup(),
        .COPYNTH => try self.copynth(op.COPYNTH),
        .SWAP => try self.swap(),
        .POP => _ = try self.pop(),

        .ADD => try self.arithmetic(.add),
        .SUB => try self.arithmetic(.sub),
        .MULT => try self.arithmetic(.mult),
        .DIV => try self.arithmetic(.div),
        .MOD => try self.arithmetic(.mod),
        .XOR => try self.arithmetic(.xor),

        .HEAPSTR => try self.heapstr(),
        .HEAPRET => try self.heapret(),

        .MARK => {},
        .CALL => try self.call(op.CALL),
        .JMP => try self.jmp(.unconditional, op.JMP),
        .JMPIF0 => try self.jmp(.iftop0, op.JMPIF0),
        .JMPIFNEG => try self.jmp(.iftopneg, op.JMPIFNEG),
        .RETURN => try self.end_subroutine(),

        .OUTCHAR => try self.outchar(stdout),
        .OUTNUM => try self.outnum(stdout),
        .INCHAR => try self.inchar(stdin),
        .INNUM => try self.innum(stdin),
    }
}

///////////////////
// Stack funcs
///////////////////

fn push(self: *Self, val: i64) VMErrors!void {
    // if (self.stack.items.len >= self.stack.capacity) {
    //     try self.stack.ensureTotalCapacity(self.stack.capacity * 2);
    // }
    try self.stack.append(val);
}

fn pop(self: *Self) VMErrors!i64 {
    return self.stack.popOrNull() orelse return VMErrors.InsufficientElements;
}

// fn resetStack(self: *Self) void {
//     self.stack.clearRetainingCapacity();
// }

fn dup(self: *Self) VMErrors!void {
    const top = self.stack.getLastOrNull() orelse return VMErrors.InsufficientElements;
    return self.push(top);
}

fn copynth(self: *Self, n: i64) VMErrors!void {
    if (self.stack.items.len < n) return VMErrors.InsufficientElements;
    const val = self.stack.items[@intCast(n)];
    return self.push(val);
}

fn swap(self: *Self) VMErrors!void {
    const items = self.stack.items;
    if (items.len < 2) return VMErrors.InsufficientElements;
    const temp: i64 = items[items.len - 1];
    items[items.len - 1] = items[items.len - 2];
    items[items.len - 2] = temp;
}

fn arithmetic(
    self: *Self,
    comptime op: enum { add, sub, mult, div, mod, xor },
) VMErrors!void {
    if (self.stack.items.len < 2) return VMErrors.InsufficientElements;
    const val = try self.pop();
    var items = self.stack.items;
    switch (op) {
        .add => items[items.len - 1] += val,
        .sub => items[items.len - 1] -= val,
        .mult => items[items.len - 1] *= val,
        .div => items[items.len - 1] = @divFloor(items[items.len - 1], val),
        .mod => items[items.len - 1] = @mod(items[items.len - 1], val),
        .xor => items[items.len - 1] ^= val,
    }
}

///////////////////
// Heap funcs
///////////////////

fn heapstr(self: *Self) VMErrors!void {
    const val = try self.pop();
    const address = try self.pop();
    for (0.., self.heap.items) |i, item| {
        if (item.address == address) {
            self.heap.items[i].val = val;
            return;
        }
    }
    try self.heap.append(.{ .address = address, .val = val });
}

fn heapret(self: *Self) VMErrors!void {
    const address = try self.pop();
    for (self.heap.items) |v| {
        if (v.address == address) {
            return self.push(v.val);
        }
    }
    return VMErrors.NoSuchElement;
}

///////////////////
// Flow control
///////////////////

fn mark(self: *Self, label: i64, pos: isize) VMErrors!void {
    // std.debug.print("Teja mai hoon Mark idhar hai ip: {d},{d}\n", .{ label, self.ip });
    try self.labels.append(.{ .name = label, .pos = pos });
}

fn call(self: *Self, label: i64) VMErrors!void {
    for (self.labels.items) |item| {
        if (item.name == label) {
            try self.call_stack.append(self.ip);
            self.ip = item.pos;
            return;
        }
    }
    return VMErrors.InvalidLabel;
}

fn jmp(
    self: *Self,
    when: enum { unconditional, iftop0, iftopneg },
    label: i64,
) VMErrors!void {
    for (self.labels.items) |item| {
        if (item.name == label) {
            // std.debug.print("jmping to {d}\n", .{item.pos});
            switch (when) {
                .unconditional => self.ip = item.pos,
                .iftop0 => {
                    const top = try self.pop();
                    if (top == 0) self.ip = item.pos;
                },
                .iftopneg => {
                    const top = try self.pop();
                    if (top < 0) self.ip = item.pos;
                },
            }
            return;
        }
    } else return VMErrors.InvalidLabel;
}

fn end_subroutine(self: *Self) VMErrors!void {
    const tojmp = self.call_stack.popOrNull() orelse return VMErrors.EmptyCallStack;
    self.ip = tojmp;
}

///////////////////
// I/O
///////////////////

fn outchar(self: *Self, stdout: std.fs.File.Writer) !void {
    const val = try self.pop();
    const usize_val = @as(usize, @intCast(val));
    try stdout.print("{c}", .{@as(u8, @truncate(usize_val))});
}

fn outnum(self: *Self, stdout: std.fs.File.Writer) !void {
    try stdout.print("{d}", .{try self.pop()});
}

fn inchar(self: *Self, stdin: std.fs.File.Reader) !void {
    const val = try stdin.readByte();
    return self.push(@intCast(val));
}

fn innum(self: *Self, stdin: std.fs.File.Reader) !void {
    const val = try stdin.readInt(i64, .little);
    return self.push(@intCast(val));
}

///////////////////
// Test
///////////////////

test "baremin" {
    const chunk = &[_]Ops{
        Ops{ .PUSH = 1 },
        Ops{ .OUTNUM = void{} },
        Ops{ .MARK = 16 }, // Main func (kkartik ka fav num)
        Ops{ .PUSH = 1 },
        Ops{ .MARK = 420 },
        Ops{ .DUP = void{} },
        Ops{ .OUTNUM = void{} },
        Ops{ .PUSH = 10 },
        Ops{ .OUTCHAR = void{} },
        Ops{ .PUSH = 1 },
        Ops{ .ADD = void{} },
        Ops{ .DUP = void{} },
        Ops{ .PUSH = 11 },
        Ops{ .SUB = void{} },
        Ops{ .JMPIF0 = 69 },
        Ops{ .JMP = 420 },
        Ops{ .MARK = 69 },
        Ops{ .POP = void{} },
        Ops{ .EXIT = void{} },
    };

    const LineInfo = @import("Chunk.zig").LineInfo;
    const lines = &[_]LineInfo{
        LineInfo{ .linenum = 1, .offset = 0 },
        LineInfo{ .linenum = 2, .offset = 2 },
        LineInfo{ .linenum = 3, .offset = 3 },
        LineInfo{ .linenum = 4, .offset = 4 },
        LineInfo{ .linenum = 5, .offset = 5 },
        LineInfo{ .linenum = 6, .offset = 6 },
        LineInfo{ .linenum = 7, .offset = 7 },
        LineInfo{ .linenum = 8, .offset = 8 },
        LineInfo{ .linenum = 9, .offset = 9 },
        LineInfo{ .linenum = 10, .offset = 10 },
        LineInfo{ .linenum = 11, .offset = 11 },
        LineInfo{ .linenum = 12, .offset = 12 },
        // LineInfo{ .linenum = 13, .offset = 13 },
        // LineInfo{ .linenum = 14, .offset = 14 },
        // LineInfo{ .linenum = 15, .offset = 15 },
        // LineInfo{ .linenum = 16, .offset = 16 },
        // LineInfo{ .linenum = 17, .offset = 17 },
        // LineInfo{ .linenum = 18, .offset = 18 },
    };

    var vm = Self.init(std.testing.allocator, Chunk{ .lines = lines, .ops = chunk });
    defer vm.deinit();
    vm.run();
    // std.debug.print("{any}\n", .{vm.stack.items});
}
