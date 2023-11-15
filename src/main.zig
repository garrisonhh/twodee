const std = @import("std");
const stderr = std.io.getStdErr().writer();
const Allocator = std.mem.Allocator;
const plugin = @import("plugin.zig");

const Args = struct {
    exe_path: [:0]const u8,
    so_path: [:0]const u8,
};

fn badArgs(comptime fmt: []const u8, args: anytype) noreturn {
    stderr.print("argument error: " ++ fmt, args) catch {};
    std.process.exit(1);
}

// TODO make this better
fn getArgs() Args {
    var args_iter = std.process.args();

    const exe_path = args_iter.next() orelse {
        badArgs("expected exe path.\n", .{});
    };

    const so_path = args_iter.next() orelse {
        badArgs("expected so path.\n", .{});
    };

    if (args_iter.next()) |arg| {
        badArgs("unexpected positional argument: {s}\n", .{arg});
    }

    return Args{
        .exe_path = exe_path,
        .so_path = so_path,
    };
}

pub fn main() !void {
    const args = getArgs();
    try plugin.run(args.so_path);
}