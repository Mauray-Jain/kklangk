const std = @import("std");
const Chunk = @import("Chunk.zig");
const Ops = Chunk.Ops;

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

allocator: std.mem.Allocator,
stack: std.ArrayList(isize),
heap: std.ArrayList(HeapVal),
labels: std.ArrayList(Label),
call_stack: std.ArrayList(isize),
chunk: Chunk,
ip: isize,

pub fn init(allocator: std.mem.Allocator, chunk: Chunk) Self {
    return Self{
        .allocator = allocator,
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

///////////////////
// Stack funcs
///////////////////

fn push(self: *Self, val: isize) std.mem.Allocator.Error!void {
    if (self.stack.items.len + 1 > self.stack.capacity) {
        try self.stack.ensureTotalCapacity(self.stack.capacity * 2);
    }
    self.stack.appendAssumeCapacity(val);
}

fn pop(self: *Self) StackErrors!isize {
    return self.stack.popOrNull() orelse return StackErrors.InsufficientElements;
}

fn resetStack(self: *Self) void {
    self.stack.clearRetainingCapacity();
}

fn dup(self: *Self) StackErrors!void {
    const top = self.stack.getLastOrNull() orelse return error{StackEmpty};
    return self.push(top);
}

fn copynth(self: *Self, n: usize) StackErrors!void {
    if (self.stack.items.len < n) return StackErrors.InsufficientElements;
    const val = self.stack.items[n];
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
        .div => items[items.len - 1] /= val,
        .mod => items[items.len - 1] %= val,
    }
}

///////////////////
// Heap funcs
///////////////////

fn store(self: *Self) StackErrors!void {
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

fn retrieve(self: *Self) (StackErrors || HeapError)!void {
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

fn reglabel(self: *Self, label: isize) AllocError!void {
    try self.labels.append(.{ .name = label, .pos = self.ip + 1 });
}

fn call(self: *Self, label: isize) LabelErrors!void {
    for (self.labels.items) |item| {
        if (item.name == label) {
            try self.call_stack.append(self.ip + 1);
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
        }
    }
}

fn end_subroutine(self: *Self) CallError!void {
    const tojmp = self.call_stack.popOrNull() orelse return CallError.EmptyCallStack;
    self.ip = tojmp;
}

///////////////////
// I/O
///////////////////

fn outc(self: *Self, stdout: std.fs.File.Writer) StackErrors!void {
    stdout.print("{c}", .{try self.pop()});
}

fn outnum(self: *Self, stdout: std.fs.File.Writer) StackErrors!void {
    stdout.print("{d}", .{try self.pop()});
}

fn readc(self: *Self, stdin: std.fs.File.Reader) !void {
    const val = try stdin.readByte();
    return self.push(@intCast(val));
}

fn readnum(self: *Self, stdin: std.fs.File.Reader) !void {
    const val = try stdin.readInt(isize, .little);
    return self.push(@intCast(val));
}
