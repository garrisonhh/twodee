//! direct interaction with sdl2 and opengl

const std = @import("std");
const stderr = std.io.getStdErr().writer();
const builtin = @import("builtin");

pub const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("epoxy/gl.h");
    @cInclude("epoxy/glx.h");
});

// helpers =====================================================================

pub const Error = error{SdlError};

fn sdlError() Error {
    if (c.SDL_GetError()) |msg| {
        stderr.print("sdl error: {s}\n", .{msg}) catch {};
    } else {
        stderr.print("sdl error (and GetError failed!)\n", .{}) catch {};
    }

    return Error.SdlError;
}

fn SdlWrapped(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .Int => void,
        .Optional => |meta| meta.child,
        else => {
            if (builtin.mode == .Debug) {
                std.debug.panic("attempted to sdl() wrap a {}", .{T});
            }
        },
    };
}

/// wrap sdl function return values. sdl has several error conventions, but they
/// are all very regular (so metaprogrammable)
fn sdl(x: anytype) Error!SdlWrapped(@TypeOf(x)) {
    const T = @TypeOf(x);
    return switch (T) {
        c_int => if (x != 0) sdlError() else {},
        c.SDL_bool => if (x != c.SDL_TRUE) sdlError() else {},
        else => switch (@typeInfo(T)) {
            .Optional => x orelse sdlError(),
            else => {
                if (builtin.mode == .Debug) {
                    std.debug.panic("attempted to sdl() wrap a {}", .{T});
                }
            },
        },
    };
}

// =============================================================================

pub var window: *c.SDL_Window = undefined;
pub var ctx: c.SDL_GLContext = undefined;

pub fn init() Error!void {
    try sdl(c.SDL_Init(c.SDL_INIT_VIDEO));

    window = try sdl(c.SDL_CreateWindow(
        "twodee",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        480,
        480,
        c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_SHOWN,
    ));

    try sdl(c.SDL_SetHint(c.SDL_HINT_RENDER_DRIVER, "opengles2"));
    try sdl(c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1));
    try sdl(c.SDL_GL_SetAttribute(c.SDL_GL_DEPTH_SIZE, 32));

    ctx = try sdl(c.SDL_GL_CreateContext(window));

    std.debug.print("got epoxy version: {}\n", .{c.epoxy_gl_version()});
}

pub fn deinit() void {
    c.SDL_GL_DeleteContext(ctx);
    c.SDL_DestroyWindow(window);
    c.SDL_Quit();
}
