//! shared objects should `export const plugin: Plugin` to be compatible with
//! twodee.

const lib = @import("lib.zig");
const So = @import("So.zig");

const Self = @This();

pub const Plugin = extern struct {
    pub const Continue = enum { ok, stop };

    init: *const fn () void,
    update: *const fn () Continue,
};

pub const Error = lib.Error || So.Error;

/// loads and runs a plugin once
pub fn run(path: [:0]const u8) Error!void {
    try lib.init();
    defer lib.deinit();

    const so = try So.open(path);
    defer so.close();

    const plug = try so.symbol("plugin", Plugin);

    plug.init();
    while (plug.update() == .ok) {}
}
