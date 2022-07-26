const std = @import("std");
const Regex = @import("regex").Regex;

fn grep(filename: []const u8, re: *Regex) !void {
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var freader = std.io.bufferedReader(file.reader());
    var r = freader.reader();

    var buf: [1024]u8 = undefined;
    var writer = std.io.getStdOut().writer();
    var i: u32 = 1;
    while (try r.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        //std.log.warn("{s}", .{line});
        if (try re.match(line)) {
            try writer.print("{s}:{}:{s}\n", .{ filename, i, line });
        }
        i += 1;
    }
}

pub fn main() anyerror!void {
    var allocator = std.heap.page_allocator;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    var prog = args.next();
    var pattern = args.next();
    if (pattern == null) {
        std.log.err("usage: {s} [pattern]", .{prog});
        std.os.exit(1);
    }

    var cwd_buf: [std.os.PATH_MAX]u8 = undefined;
    var cwd = try std.process.getCwd(&cwd_buf);
    var absolute_path = try std.fs.path.joinZ(allocator, &.{ cwd_buf[0..cwd.len], "." });

    var dir = try std.fs.openIterableDirAbsolute(absolute_path, .{});
    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var re = try Regex.compile(allocator, pattern.?);

    while (try walker.next()) |entry| {
        if (entry.path[0] == '.') continue;
        if (entry.kind != std.fs.IterableDir.Entry.Kind.File) continue;
        if (std.mem.startsWith(u8, entry.path, "zig-cache")) continue;
        if (std.mem.startsWith(u8, entry.path, "zig-out")) continue;
        try grep(entry.path, &re);
    }
}
