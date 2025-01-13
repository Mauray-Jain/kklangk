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
    while (true) : (self.current += 1) {
        switch (self.src[self.current]) {
            ' ', '\t', '\r' => {},
            '\n' => self.line += 1,
            else => return,
        }
    }
}

fn skipWord(self: *Self) void {
    while (true) : (self.current += 1) {
        switch (self.src[self.current]) {
            ' ', '\r', '\t' => return,
            '\n' => {
                self.line += 1;
                return;
            },
            else => continue,
        }
    }
}

pub fn scanToken(self: *Self) Token {
    while (self.current < self.src.len) {
        self.skipWhitespace();
        self.start = self.current;
        switch (self.src[self.current]) {
            'a' => return self.checkKeyword("sa", Token{ .ASA = self.line }),
            'b' => return self.checkKeyword("elle", Token{ .BELLE = self.line }),
            'c' => return self.checkKeyword("huss", Token{ .CHUSS = self.line }),
            'g' => return self.checkKeyword("oiz", Token{ .GOIZ = self.line }),
            'h' => return self.checkKeyword("orr", Token{ .HORR = self.line }),
            's' => return self.checkKeyword("aade", Token{ .SAADE = self.line }),
            't' => return self.checkKeyword("uh", Token{ .TUH = self.line }),
            'y' => return self.checkKeyword("eh", Token{ .YEH = self.line }),
            else => self.skipWord(), // everything else is ignored,
        }
    }
    return Token{ .EOF = void{} };
}
