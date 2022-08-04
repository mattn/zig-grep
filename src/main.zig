const std = @import("std");
const Regex = @import("regex").Regex;

fn grep(filename: []const u8, re: *Regex) !void {
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var freader = std.io.bufferedReader(file.reader());
    var r = freader.reader();

    var buf: [4096]u8 = undefined;
    var writer = std.io.getStdOut().writer();
    var i: u32 = 1;
    while (true) {
        var line = r.readUntilDelimiterOrEof(buf[0..buf.len], '\n') catch null;
        if (line == null) break;
        if (try re.partialMatch(line.?)) {
            try writer.print("{s}:{}:{s}\n", .{ filename, i, line.? });
        }
        i += 1;
    } else |err| {
        std.log.warn("{}", .{err});
    }
}

pub fn main() anyerror!void {
    var allocator = std.heap.page_allocator;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    var prog = args.next();
    var pattern = args.next();
    if (pattern == null) {
        std.log.err("usage: {s} [pattern]", .{prog.?});
        std.os.exit(1);
    }

    var cwd_buf: [std.os.PATH_MAX]u8 = undefined;
    var cwd = try std.process.getCwd(&cwd_buf);

    var dir = try std.fs.openIterableDirAbsolute(cwd, .{});
    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var re = try Regex.compile(allocator, pattern.?);

    while (try walker.next()) |entry| {
        if (entry.path[0] == '.') continue;
        if (entry.kind != std.fs.IterableDir.Entry.Kind.File) continue;
        if (std.mem.startsWith(u8, entry.path, "zig-cache")) continue;
        if (std.mem.startsWith(u8, entry.path, "zig-out")) continue;
        if (std.mem.endsWith(u8, entry.path, ".o")) continue;
        if (std.mem.endsWith(u8, entry.path, ".obj")) continue;
        if (std.mem.endsWith(u8, entry.path, ".png")) continue;
        if (std.mem.endsWith(u8, entry.path, ".exe")) continue;
        if (std.mem.endsWith(u8, entry.path, ".lib")) continue;
        try grep(entry.path, &re);
    }
}
