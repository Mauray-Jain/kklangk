const std = @import("std");

pub const Token = union(enum) {
    ASA: usize,
    BELLE: usize,
    CHUSS: usize,
    GOIZ: usize,
    HORR: usize,
    SAADE: usize,
    TUH: usize,
    YEH: usize,
    EOF: void,

    pub fn disas(val: @This()) void {
        const tag = @tagName(val);
        inline for (std.meta.fields(@This())) |f| { // doing bcoz in @field the name shld be comptime known
            if (std.mem.eql(u8, f.name, tag)) {
                std.debug.print("{} {s}\n", .{ @field(val, f.name), f.name });
            }
        }
    }
};

const Self = @This();

start: usize,
current: usize,
line: usize,
src: []const u8,

pub fn init(src: []const u8) Self {
    return Self{
        .start = 0,
        .current = 0,
        .line = 1,
        .src = src,
    };
}

fn skipWhitespace(self: *Self) void {
    while (self.current < self.src.len) : (self.current += 1) {
        switch (self.src[self.current]) {
            ' ', '\t', '\r' => {},
            '\n' => self.line += 1,
            else => return,
        }
    }
}

fn consumeWord(self: *Self) void {
    while (self.current < self.src.len and std.ascii.isAlphabetic(self.src[self.current]))
        self.current += 1;
}

fn checkKeyword(self: *const Self, rest: []const u8, token: Token) error{Missing}!Token {
    if (std.mem.eql(u8, rest, self.src[self.start + 1 .. self.current])) {
        return token;
    }
    return error.Missing;
}

pub fn scanToken(self: *Self) Token {
    while (self.current < self.src.len) {
        self.skipWhitespace();
        self.start = self.current;
        self.consumeWord();
        // std.debug.print("{s}\n", .{self.src[self.start..self.current]});
        switch (self.src[self.start]) {
            'a' => return self.checkKeyword("sa", Token{ .ASA = self.line }) catch continue,
            'b' => return self.checkKeyword("elle", Token{ .BELLE = self.line }) catch continue,
            'c' => return self.checkKeyword("huss", Token{ .CHUSS = self.line }) catch continue,
            'g' => return self.checkKeyword("oiz", Token{ .GOIZ = self.line }) catch continue,
            'h' => return self.checkKeyword("orr", Token{ .HORR = self.line }) catch continue,
            's' => return self.checkKeyword("aade", Token{ .SAADE = self.line }) catch continue,
            't' => return self.checkKeyword("uh", Token{ .TUH = self.line }) catch continue,
            'y' => return self.checkKeyword("eh", Token{ .YEH = self.line }) catch continue,
            else => {}, // everything else is ignored
        }
    }
    return Token{ .EOF = void{} };
}

test "toktok" {
    const src: []const u8 =
        \\  asaaa as    a asa saade
        \\belle goiz dsl
        \\yeh byeh
    ;

    // const src =
    //     \\asa
    // ;

    var token: Token = undefined;
    var scanner = Self.init(src);

    while (true) {
        token = scanner.scanToken();
        token.disas();
        switch (token) {
            .EOF => break,
            else => {},
        }
    }
}
