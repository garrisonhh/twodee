const std = @import("std");
const twodee = @import("twodee");

export const plugin = twodee.Plugin{
    .update = &update,
};

fn update(events: []const twodee.Event) void {
    for (events) |event| {
        switch (event) {
            .keydown => |kb| {
                std.debug.print(
                    "[{s}] {s}\n",
                    .{ @tagName(event), @tagName(kb.keysym.keycode) },
                );
            },

            else => {},
        }
    }
}
