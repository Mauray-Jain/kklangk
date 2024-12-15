const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const Ops = @import("chunk.zig").Ops;

const Self = @This();

const AllocError = std.mem.Allocator.Error;
pub const StackErrors = error{InsufficientElements} || AllocError;
pub const HeapError = error{NoSuchElement};
pub const LabelErrors = error{InvalidLabel} || AllocError;
pub const CallError = error{EmptyCallStack};

pub const HeapVal = struct {
    address: isize,
    val: isize,
};

pub const Label = struct {
    name: isize,
    pos: isize,
};

stack: std.ArrayList(isize),
heap: std.ArrayList(HeapVal),
labels: std.ArrayList(Label),
call_stack: std.ArrayList(isize),
chunk: Chunk,
ip: isize,

pub fn init(allocator: std.mem.Allocator, chunk: Chunk) Self {
    return Self{
        .stack = std.ArrayList(isize).init(allocator),
        .heap = std.ArrayList(HeapVal).init(allocator),
        .labels = std.ArrayList(Label).init(allocator),
        .call_stack = std.ArrayList(isize).init(allocator),
        .chunk = chunk,
        .ip = 0,
    };
}

pub fn deinit(self: *Self) void {
    self.stack.deinit();
    self.heap.deinit();
    self.labels.deinit();
    self.call_stack.deinit();
    self.ip = 0;
}

pub fn run(self: *Self) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    // Main label is 16
    var main: isize = @as(isize, @intCast(self.chunk.len));

    while (self.ip < self.chunk.len) : (self.ip += 1) {
        const op = self.chunk[@intCast(self.ip)];
        switch (op) {
            .MARK => {
                try self.mark(op.MARK);
                if (op.MARK == 16) {
                    main = self.ip;
                }
            },
            else => {},
        }
    }

    self.ip = main;

    while (self.ip < self.chunk.len) : (self.ip += 1) {
        // std.debug.print("{any}\n", .{self.stack.items});
        const op = self.chunk[@intCast(self.ip)];
        switch (op) {
            .EXIT => {
                self.ip = @as(isize, @intCast(self.chunk.len));
                return;
            },
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
}

///////////////////
// Stack funcs
///////////////////

fn push(self: *Self, val: isize) std.mem.Allocator.Error!void {
    // if (self.stack.items.len >= self.stack.capacity) {
    //     try self.stack.ensureTotalCapacity(self.stack.capacity * 2);
    // }
    try self.stack.append(val);
}

fn pop(self: *Self) StackErrors!isize {
    return self.stack.popOrNull() orelse return StackErrors.InsufficientElements;
}

fn resetStack(self: *Self) void {
    self.stack.clearRetainingCapacity();
}

fn dup(self: *Self) StackErrors!void {
    const top = self.stack.getLastOrNull() orelse return StackErrors.InsufficientElements;
    return self.push(top);
}

fn copynth(self: *Self, n: isize) StackErrors!void {
    if (self.stack.items.len < n) return StackErrors.InsufficientElements;
    const val = self.stack.items[@intCast(n)];
    return self.push(val);
}

fn swap(self: *Self) StackErrors!void {
    const items = self.stack.items;
    if (items.len < 2) return StackErrors.InsufficientElements;
    const temp: isize = items[items.len - 1];
    items[items.len - 1] = items[items.len - 2];
    items[items.len - 2] = temp;
}

fn arithmetic(
    self: *Self,
    comptime op: enum { add, sub, mult, div, mod },
) StackErrors!void {
    if (self.stack.items.len < 2) return StackErrors.InsufficientElements;
    const val = try self.pop();
    var items = self.stack.items;
    switch (op) {
        .add => items[items.len - 1] += val,
        .sub => items[items.len - 1] -= val,
        .mult => items[items.len - 1] *= val,
        .div => items[items.len - 1] = @divFloor(items[items.len - 1], val),
        .mod => items[items.len - 1] = @mod(items[items.len - 1], val),
    }
}

///////////////////
// Heap funcs
///////////////////

fn heapstr(self: *Self) StackErrors!void {
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

fn heapret(self: *Self) (StackErrors || HeapError)!void {
    const address = try self.pop();
    for (self.heap.items) |v| {
        if (v.address == address) {
            return self.push(v.val);
        }
    }
    return HeapError.NoSuchElement;
}

///////////////////
// Flow control
///////////////////

fn mark(self: *Self, label: isize) AllocError!void {
    // std.debug.print("Mark idhar hai ip: {d},{d}\n", .{ label, self.ip });
    try self.labels.append(.{ .name = label, .pos = self.ip });
}

fn call(self: *Self, label: isize) LabelErrors!void {
    for (self.labels.items) |item| {
        if (item.name == label) {
            try self.call_stack.append(self.ip);
            self.ip = item.pos;
            return;
        }
    }
    return LabelErrors.InvalidLabel;
}

fn jmp(
    self: *Self,
    when: enum { unconditional, iftop0, iftopneg },
    label: isize,
) (StackErrors || LabelErrors)!void {
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
    } else return LabelErrors.InvalidLabel;
}

fn end_subroutine(self: *Self) CallError!void {
    const tojmp = self.call_stack.popOrNull() orelse return CallError.EmptyCallStack;
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
    const val = try stdin.readInt(isize, .little);
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
    var vm = Self.init(std.testing.allocator, chunk);
    defer vm.deinit();
    try vm.run();
    // std.debug.print("{any}\n", .{vm.stack.items});
}
