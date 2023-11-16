//! plugin management stuff

const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib.zig");
const c = lib.c;
const Event = @import("sdl/event.zig").Event;
const So = @import("So.zig");

const Self = @This();

/// twodee plugins should `export const plugin: Plugin`
pub const Plugin = extern struct {
    init: ?*const fn () void = null,
    update: ?*const fn ([]const Event) void = null,
};

pub const Error = Allocator.Error || lib.InitError || So.Error || lib.GlError;

/// loads and runs a plugin once
pub fn run(path: [:0]const u8) Error!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const ally = gpa.allocator();

    try lib.init();
    defer lib.deinit();

    const so = try So.open(path);
    defer so.close();

    const plug = try so.symbol("plugin", Plugin);

    if (plug.init) |init_fn| init_fn();

    var events = std.ArrayListUnmanaged(Event){};
    defer events.deinit(ally);

    var keep_running = true;
    while (keep_running) {
        while (Event.poll()) |event| {
            if (plug.update != null) {
                try events.append(ally, event);
            }

            switch (event) {
                .quit => {
                    keep_running = false;
                },
                else => {},
            }
        }

        if (plug.update) |update_fn| {
            update_fn(events.items);
            events.items.len = 0;
        }

        try lib.draw();
    }
}

// TODO watch()