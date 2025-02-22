const std = @import("std");
const Tokenizer = @import("Tokenizer.zig");
const Token = @import("Tokenizer.zig").Token;
const Ops = @import("Chunk.zig").Ops;
const LineInfo = @import("Chunk.zig").LineInfo;

tokenizer: Tokenizer,
ops: std.ArrayList(Ops),
line_info: std.ArrayList(LineInfo),

const Self = @This();

pub fn init(allocator: std.mem.Allocator, src: []const u8) Self {
    return Self{
        .tokenizer = Tokenizer.init(src),
        .ops = std.ArrayList(Ops).init(allocator),
        .line_info = std.ArrayList(LineInfo).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.ops.deinit();
    self.line_info.deinit();
}
