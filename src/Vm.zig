const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const Ops = @import("chunk.zig").Ops;

const Self = @This();

const AllocError = std.mem.Allocator.Error;
pub const VMErrors = error{
    InsufficientElements,
    EmptyCallStack,
    InvalidLabel,
    NoSuchElement,
} || AllocError;

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

fn handleErr(self: *Self, err: anyerror) noreturn {
    const line = self.chunk.getLine(@intCast(self.ip));
    const msg = switch (err) {
        VMErrors.OutOfMemory => "Ran out of heap memory! Get a better computer sucker!",
        VMErrors.EmptyCallStack => "Nowhere to return to",
        VMErrors.InvalidLabel => "Hey that label doesnt exist",
        VMErrors.NoSuchElement => "No such element on the heap",
        VMErrors.InsufficientElements => "Not enough elements on stack to do this",
        else => @errorName(err),
    };
    std.debug.print("Line {d}:\n\t{s}: {s}\n", .{ line, @errorName(err), msg });
    self.deinit();
    std.process.exit(1);
}

pub fn run(self: *Self) void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    // Main label is 16
    self.ip = @as(isize, @intCast(self.chunk.ops.len));

    for (self.chunk.ops, 0..) |op, pos| {
        switch (op) {
            .MARK => {
                self.mark(op.MARK, @intCast(pos)) catch |err| self.handleErr(err);
                if (op.MARK == 16) {
                    self.ip = @intCast(pos);
                }
            },
            else => {},
        }
    }

    while (self.ip < self.chunk.ops.len) : (self.ip += 1) {
        // std.debug.print("{any}\n", .{self.stack.items});
        const op = self.chunk.ops[@intCast(self.ip)];
        switch (op) {
            .EXIT => {
                self.ip = @as(isize, @intCast(self.chunk.ops.len));
                return;
            },
            .PUSH => self.push(op.PUSH) catch |err| self.handleErr(err),
            .DUP => self.dup() catch |err| self.handleErr(err),
            .COPYNTH => self.copynth(op.COPYNTH) catch |err| self.handleErr(err),
            .SWAP => self.swap() catch |err| self.handleErr(err),
            .POP => _ = self.pop() catch |err| self.handleErr(err),

            .ADD => self.arithmetic(.add) catch |err| self.handleErr(err),
            .SUB => self.arithmetic(.sub) catch |err| self.handleErr(err),
            .MULT => self.arithmetic(.mult) catch |err| self.handleErr(err),
            .DIV => self.arithmetic(.div) catch |err| self.handleErr(err),
            .MOD => self.arithmetic(.mod) catch |err| self.handleErr(err),

            .HEAPSTR => self.heapstr() catch |err| self.handleErr(err),
            .HEAPRET => self.heapret() catch |err| self.handleErr(err),

            .MARK => {},
            .CALL => self.call(op.CALL) catch |err| self.handleErr(err),
            .JMP => self.jmp(.unconditional, op.JMP) catch |err| self.handleErr(err),
            .JMPIF0 => self.jmp(.iftop0, op.JMPIF0) catch |err| self.handleErr(err),
            .JMPIFNEG => self.jmp(.iftopneg, op.JMPIFNEG) catch |err| self.handleErr(err),
            .RETURN => self.end_subroutine() catch |err| self.handleErr(err),

            .OUTCHAR => self.outchar(stdout) catch |err| self.handleErr(err),
            .OUTNUM => self.outnum(stdout) catch |err| self.handleErr(err),
            .INCHAR => self.inchar(stdin) catch |err| self.handleErr(err),
            .INNUM => self.innum(stdin) catch |err| self.handleErr(err),
        }
    }
}

///////////////////
// Stack funcs
///////////////////

fn push(self: *Self, val: isize) VMErrors!void {
    // if (self.stack.items.len >= self.stack.capacity) {
    //     try self.stack.ensureTotalCapacity(self.stack.capacity * 2);
    // }
    try self.stack.append(val);
}

fn pop(self: *Self) VMErrors!isize {
    return self.stack.popOrNull() orelse return VMErrors.InsufficientElements;
}

fn resetStack(self: *Self) void {
    self.stack.clearRetainingCapacity();
}

fn dup(self: *Self) VMErrors!void {
    const top = self.stack.getLastOrNull() orelse return VMErrors.InsufficientElements;
    return self.push(top);
}

fn copynth(self: *Self, n: isize) VMErrors!void {
    if (self.stack.items.len < n) return VMErrors.InsufficientElements;
    const val = self.stack.items[@intCast(n)];
    return self.push(val);
}

fn swap(self: *Self) VMErrors!void {
    const items = self.stack.items;
    if (items.len < 2) return VMErrors.InsufficientElements;
    const temp: isize = items[items.len - 1];
    items[items.len - 1] = items[items.len - 2];
    items[items.len - 2] = temp;
}

fn arithmetic(
    self: *Self,
    comptime op: enum { add, sub, mult, div, mod },
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

fn mark(self: *Self, label: isize, pos: isize) VMErrors!void {
    // std.debug.print("Mark idhar hai ip: {d},{d}\n", .{ label, self.ip });
    try self.labels.append(.{ .name = label, .pos = pos });
}

fn call(self: *Self, label: isize) VMErrors!void {
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
    label: isize,
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

    const LineInfo = @import("chunk.zig").LineInfo;
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
