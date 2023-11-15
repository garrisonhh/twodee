const std = @import("std");
const twodee = @import("twodee");
const Plugin = twodee.Plugin;

export const plugin = Plugin{
    .init = &init,
    .update = &update,
};

pub fn init() void {
    std.debug.print("hello, twodee!\n", .{});
}

pub fn update() Plugin.Continue {
    while (twodee.pollEvent()) |event| {
        switch (event) {
            .quit => {
                return .stop;
            },

            .keyup => |kb| {
                std.debug.print(
                    "[{s}] {s}\n",
                    .{ @tagName(event), @tagName(kb.keysym.keycode) },
                );
            },

            else => {},
        }
    }

    return .ok;
}
