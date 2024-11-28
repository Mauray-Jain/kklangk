const std = @import("std");

const Self = @This();

pub const StackErrors = error{InsufficientElements} || std.mem.Allocator.Error;
pub const HeapError = error{NoSuchElement};

pub const HeapVal = struct {
    address: isize,
    val: isize,
};

allocator: std.mem.Allocator,
stack: std.ArrayList(isize),
heap: std.ArrayList(HeapVal),
labels: std.ArrayList(isize),

pub fn init(allocator: std.mem.Allocator) Self {
    return Self{
        .allocator = allocator,
        .stack = std.ArrayList(isize).init(allocator),
        .heap = std.ArrayList(HeapVal).init(allocator),
        .labels = std.ArrayList(isize).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.stack.deinit();
    self.heap.deinit();
    self.labels.deinit();
}

///////////////////
// Stack funcs
///////////////////

pub fn push(self: *Self, val: isize) std.mem.Allocator.Error!void {
    if (self.stack.items.len + 1 > self.stack.capacity) {
        try self.stack.ensureTotalCapacity(self.stack.capacity * 2);
    }
    self.stack.appendAssumeCapacity(val);
}

pub fn pop(self: *Self) StackErrors!isize {
    return self.stack.popOrNull() orelse return StackErrors.InsufficientElements;
}

pub fn resetStack(self: *Self) void {
    self.stack.clearRetainingCapacity();
}

pub fn dup(self: *Self) StackErrors!void {
    const top = self.stack.getLastOrNull() orelse return error{StackEmpty};
    return self.push(top);
}

pub fn copynth(self: *Self, n: usize) StackErrors!void {
    if (self.stack.items.len < n) return StackErrors.InsufficientElements;
    const val = self.stack.items[n];
    return self.push(val);
}

pub fn swap(self: *Self) StackErrors!void {
    const items = self.stack.items;
    if (items.len < 2) return StackErrors.InsufficientElements;
    const temp: isize = items[items.len - 1];
    items[items.len - 1] = items[items.len - 2];
    items[items.len - 2] = temp;
}

pub fn arithmetic(
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

pub fn store(self: *Self) StackErrors!void {
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

pub fn retrieve(self: *Self) (StackErrors || HeapError)!void {
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

pub fn reglabel(self: *Self) void {
    _ = self;
}

///////////////////
// I/O
///////////////////

pub fn outc(self: *Self, stdout: std.fs.File.Writer) StackErrors!void {
    stdout.print("{c}", .{try self.pop()});
}

pub fn outnum(self: *Self, stdout: std.fs.File.Writer) StackErrors!void {
    stdout.print("{d}", .{try self.pop()});
}

pub fn readc(self: *Self, stdin: std.fs.File.Reader) !void {
    const val = try stdin.readByte();
    return self.push(@intCast(val));
}

pub fn readnum(self: *Self, stdin: std.fs.File.Reader) !void {
    const val = try stdin.readInt(isize, .little);
    return self.push(@intCast(val));
}
