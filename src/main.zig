const std = @import("std");
const Parser = @import("Parser.zig");
const ParseErrors = @import("Parser.zig").ParseErrors;
const Vm = @import("Vm.zig");
const VMErrors = @import("Vm.zig").VMErrors;

pub fn main() u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Mem management skill issue unlocked", .{});
    // const allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    var argIterator = std.process.ArgIterator.initWithAllocator(allocator) catch {
        printHelp("Get some memory brdr");
        return 1;
    };
    defer argIterator.deinit();
    _ = argIterator.next();

    const filePath = argIterator.next() orelse {
        printHelp("");
        return 1;
    };

    var file = std.fs.cwd().openFile(filePath, .{}) catch {
        printHelp("");
        return 1;
    };
    const reader = file.reader();

    const buf = reader.readAllAlloc(allocator, std.math.maxInt(usize)) catch {
        printHelp("Couldnt read file");
        return 1;
    };
    defer allocator.free(buf);

    var parser = Parser.init(allocator, buf);
    parser.populateBytecode() catch |err| {
        handleParseErr(&parser, err);
        return 1;
    };
    const chunk = parser.makeChunk() catch return 1;
    defer allocator.free(chunk.lines);
    defer allocator.free(chunk.ops);

    var vm = Vm.init(allocator, chunk);
    defer vm.deinit();
    vm.run() catch |err| {
        handleVmErr(&vm, err);
        return 1;
    };

    return 0;
}

fn handleParseErr(parser: *Parser, err: anyerror) void {
    const msg = switch (err) {
        ParseErrors.InvalidCommand => "I have no memory of this command",
        ParseErrors.InvalidOperationOnStack => "Why tf are you trying to pull a pushdoor??",
        ParseErrors.InvalidArithmeticOperation => "I do not know so much math",
        ParseErrors.InvalidOperationOnHeap => "Hippity hoppity heap isnt ur property",
        ParseErrors.InvalidControlFlowOperation => "Where are you leading me?? To the abyss??",
        ParseErrors.InvalidIOOperation => "Broo! How tf did you manage to mess up IO",
        ParseErrors.EndOfFile => unreachable,
        else => @errorName(err),
    };
    var stderr = std.io.getStdErr().writer();
    stderr.print("Line {d}:\n\t{s}: {s}\n", .{ parser.line, @errorName(err), msg }) catch {};
    parser.deinit();
}

fn handleVmErr(vm: *Vm, err: anyerror) void {
    const line = vm.chunk.getLine(@intCast(vm.ip));
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
    vm.deinit();
}

fn printHelp(msg: []const u8) void {
    const stderr = std.io.getStdErr().writer();
    if (!std.mem.eql(u8, "", msg))
        stderr.print("{s}\n", .{msg}) catch {};
    stderr.print(
        \\Help:
        \\  kklangk[.exe] file
        \\
    , .{}) catch {};
}
