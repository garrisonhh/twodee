//! direct interaction with sdl2 and opengl

const std = @import("std");
const stderr = std.io.getStdErr().writer();
const builtin = @import("builtin");

pub const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("epoxy/gl.h");
    // @cInclude("epoxy/glx.h");
});

// helpers =====================================================================

pub const GlError = error {
    GlInvalidEnum,
    GlInvalidValue,
    GlInvalidOperation,
    GlStackOverflow,
    GlStackUnderflow,
    GlOutOfMemory,
    GlInvalidFramebufferOperation,
};

pub const SdlError = error{SdlError};

/// checks gl errors
pub fn glCheck() GlError!void {
    const err_code = c.glGetError();
    if (err_code != c.GL_NO_ERROR) {
        return switch (err_code) {
            c.GL_INVALID_ENUM => GlError.GlInvalidEnum,
            c.GL_INVALID_VALUE => GlError.GlInvalidValue,
            c.GL_INVALID_OPERATION => GlError.GlInvalidOperation,
            c.GL_STACK_OVERFLOW => GlError.GlStackOverflow,
            c.GL_STACK_UNDERFLOW => GlError.GlStackUnderflow,
            c.GL_OUT_OF_MEMORY => GlError.GlOutOfMemory,
            c.GL_INVALID_FRAMEBUFFER_OPERATION => GlError.GlInvalidFramebufferOperation,
            else => unreachable,
        };
    }
}

fn sdlError() SdlError {
    if (c.SDL_GetError()) |msg| {
        stderr.print("sdl error: {s}\n", .{msg}) catch {};
    } else {
        stderr.print("sdl error (and GetError failed!)\n", .{}) catch {};
    }

    return SdlError.SdlError;
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
fn sdl(x: anytype) SdlError!SdlWrapped(@TypeOf(x)) {
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

const ShaderError = error {
    CreateShaderFailed,
    CompileShaderFailed,
    CreateProgramFailed,
    LinkProgramFailed,
};

pub const InitError = GlError || SdlError || ShaderError;

pub var window: *c.SDL_Window = undefined;
pub var ctx: c.SDL_GLContext = undefined;

var program: c.GLuint = undefined;
var vert_shader: c.GLuint = undefined;
var frag_shader: c.GLuint = undefined;

const v_position = 0;

pub fn init() InitError!void {
    // sdl2 window
    try sdl(c.SDL_Init(c.SDL_INIT_VIDEO));

    window = try sdl(c.SDL_CreateWindow(
        "twodee",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        480,
        480,
        c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_SHOWN,
    ));
    errdefer c.SDL_DestroyWindow(window);

    // opengl context
    try sdl(c.SDL_SetHint(c.SDL_HINT_RENDER_DRIVER, "opengles2"));
    try sdl(c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1));
    try sdl(c.SDL_GL_SetAttribute(c.SDL_GL_DEPTH_SIZE, 32));

    ctx = try sdl(c.SDL_GL_CreateContext(window));
    errdefer c.SDL_GL_DeleteContext(ctx);

    try sdl(c.SDL_GL_MakeCurrent(window, ctx));

    // shader stuff
    program = c.glCreateProgram();
    if (program == 0) return ShaderError.CreateProgramFailed;
    errdefer c.glDeleteProgram(program);

    const vert_source = @embedFile("shaders/tri_vert.glsl");
    const frag_source = @embedFile("shaders/tri_frag.glsl");

    vert_shader = try loadShader(vert_source, .vert);
    errdefer c.glDeleteShader(vert_shader);
    frag_shader = try loadShader(frag_source, .frag);
    errdefer c.glDeleteShader(frag_shader);

    c.glAttachShader(program, vert_shader);
    try glCheck();
    c.glAttachShader(program, frag_shader);
    try glCheck();

    c.glBindAttribLocation(program, v_position, "v_position");
    try glCheck();

    c.glLinkProgram(program);
    try glCheck();

    var linked: c.GLint = undefined;
    c.glGetProgramiv(program, c.GL_LINK_STATUS, &linked);
    if (linked != c.GL_TRUE) {
        var buf: [1024]u8 = undefined;
        var len: c.GLsizei = undefined;
        c.glGetProgramInfoLog(program, buf.len, &len, &buf);

        const msg = buf[0..@intCast(len)];
        stderr.print("error linking program: {s}\n", .{msg}) catch {};
        return ShaderError.LinkProgramFailed;
    }

    // fixup stuff
    try updateViewport();
}

pub fn deinit() void {
    c.glDeleteShader(frag_shader);
    c.glDeleteShader(vert_shader);
    c.glDeleteProgram(program);
    c.SDL_GL_DeleteContext(ctx);
    c.SDL_DestroyWindow(window);
    c.SDL_Quit();
}

const ShaderKind = enum { vert, frag };

fn loadShader(
    source: [:0]const u8,
    kind: ShaderKind,
) (GlError || ShaderError)!c.GLuint {
    // create shader
    const shader = c.glCreateShader(switch (kind) {
        .vert => c.GL_VERTEX_SHADER,
        .frag => c.GL_FRAGMENT_SHADER,
    });

    if (shader == 0) return ShaderError.CreateShaderFailed;

    // compile source
    c.glShaderSource(shader, 1, &source.ptr, null);
    try glCheck();
    c.glCompileShader(shader);
    try glCheck();

    var compiled: c.GLint = undefined;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &compiled);
    if (compiled != c.GL_TRUE) {
        var buf: [1024]u8 = undefined;
        var len: c.GLsizei = undefined;
        c.glGetShaderInfoLog(shader, buf.len, &len, &buf);

        const msg = buf[0..@intCast(len)];
        stderr.print("error compiling shader: {s}\n", .{msg}) catch {};
        return ShaderError.CompileShaderFailed;
    }

    return shader;
}

/// updates opengl viewport to match window size. call on init and window resize
fn updateViewport() GlError!void {
    var w: c_int = undefined;
    var h: c_int = undefined;
    c.SDL_GetWindowSize(window, &w, &h);
    c.glViewport(0, 0, w, h);
    try glCheck();
}

/// does shader call
pub fn draw() GlError!void {
    const triangle = [_]c.GLfloat{
        0.0, 0.5, 0.0,
        -0.5, -0.5, 0.0,
        0.5, -0.5, 0.0,
    };

    c.glClear(c.GL_COLOR_BUFFER_BIT);
    try glCheck();

    c.glUseProgram(program);
    try glCheck();

    c.glVertexAttribPointer(
        v_position,
        3,
        c.GL_FLOAT,
        c.GL_FALSE,
        0,
        &triangle,
    );
    try glCheck();

    c.glEnableVertexAttribArray(v_position);
    try glCheck();

    c.glDrawArrays(c.GL_TRIANGLES, 0, 3);
    try glCheck();

    c.SDL_GL_SwapWindow(window);
}
