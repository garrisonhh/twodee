const c = @import("../lib.zig").c;
const Keysym = @import("keys.zig").Keysym;

/// an sdl event mapped to zig constructs
pub const Event = union(enum) {
    const Self = @This();

    pub const Keyboard = struct {
        pub const State = enum { pressed, released };

        timestamp: u32,
        window_id: u32,
        state: State,
        keysym: Keysym,
    };

    quit,
    keydown: Keyboard,
    keyup: Keyboard,

    pub fn from(raw: c.SDL_Event) ?Self {
        return switch (@as(EventType, @enumFromInt(raw.type))) {
            .quit => .quit,

            inline .keydown,
            .keyup,
            => |tag| @unionInit(Self, @tagName(tag), Keyboard{
                .timestamp = raw.key.timestamp,
                .window_id = raw.key.windowID,
                .state = switch (raw.key.state) {
                    c.SDL_PRESSED => .pressed,
                    c.SDL_RELEASED => .released,
                    else => unreachable,
                },
                .keysym = Keysym.from(raw.key.keysym),
            }),

            else => null,
        };
    }

    /// retrieves and converts events through SDL_PollEvent
    pub fn poll() ?Event {
        var raw: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&raw) != 0) {
            if (from(raw)) |event| {
                return event;
            }
        }

        return null;
    }
};

pub const EventType = enum(c_int) {
    quit = 0x100,
    app_terminating = 0x101,
    app_lowmemory = 0x102,
    app_willenterbackground = 0x103,
    app_didenterbackground = 0x104,
    app_willenterforeground = 0x105,
    app_didenterforeground = 0x106,
    displayevent = 0x150,
    windowevent = 0x200,
    syswmevent = 0x201,
    keydown = 0x300,
    keyup = 0x301,
    textediting = 0x302,
    textinput = 0x303,
    keymapchanged = 0x304,
    mousemotion = 0x400,
    mousebuttondown = 0x401,
    mousebuttonup = 0x402,
    mousewheel = 0x403,
    joyaxismotion = 0x600,
    joyballmotion = 0x601,
    joyhatmotion = 0x602,
    joybuttondown = 0x603,
    joybuttonup = 0x604,
    joydeviceadded = 0x605,
    joydeviceremoved = 0x606,
    controlleraxismotion = 0x650,
    controllerbuttondown = 0x651,
    controllerbuttonup = 0x652,
    controllerdeviceadded = 0x653,
    controllerdeviceremoved = 0x654,
    controllerdeviceremapped = 0x655,
    fingerdown = 0x700,
    fingerup = 0x701,
    fingermotion = 0x702,
    dollargesture = 0x800,
    dollarrecord = 0x801,
    multigesture = 0x802,
    clipboardupdate = 0x900,
    dropfile = 0x1000,
    droptext = 0x1001,
    dropbegin = 0x1002,
    dropcomplete = 0x1003,
    audiodeviceadded = 0x1100,
    audiodeviceremoved = 0x1101,
    sensorupdate = 0x1200,
    render_targets_reset = 0x2000,
    render_device_reset = 0x2001,
};
