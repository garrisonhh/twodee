//! namespace exported for plugins. interacts directly with lib.

const lib = @import("lib.zig");
const c = lib.c;

pub usingnamespace @import("sdl/keys.zig");
pub usingnamespace @import("sdl/event.zig");

const Event = @This().Event;

/// iterator over sdl events
pub fn pollEvent() ?Event {
    // attempt to find the first event which is currently possible to translate
    var raw: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&raw) != 0) {
        if (Event.from(raw)) |event| {
            return event;
        }
    }

    return null;
}
