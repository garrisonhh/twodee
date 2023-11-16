//! shader loader, specialized for application to twodee

const std = @import("std");
const stderr = std.io.getStdErr().writer();
const lib = @import("../lib.zig");
const c = lib.c;

const Self = @This();

pub const Kind = enum { vert, frag };

const LoadError = error {
    CreateShaderFailed,
    CompileShaderFailed,
};

pub const InitError = LoadError || lib.GlError;

handle: c.GLuint,

/// source must outlive shader
pub fn init(source: [:0]const u8, kind: Kind) InitError!Self {
    // create shader
    const shader = c.glCreateShader(switch (kind) {
        .vert => c.GL_VERTEX_SHADER,
        .frag => c.GL_FRAGMENT_SHADER,
    });

    if (shader == 0) return LoadError.CreateShaderFailed;

    // compile source
    c.glShaderSource(shader, 1, &source.ptr, null);
    try lib.glCheck();
    c.glCompileShader(shader);
    try lib.glCheck();

    var compiled: c.GLint = undefined;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &compiled);
    if (compiled != c.GL_TRUE) {
        var buf: [1024]u8 = undefined;
        var len: c.GLsizei = undefined;
        c.glGetShaderInfoLog(shader, buf.len, &len, &buf);

        const msg = buf[0..@intCast(len)];
        stderr.print("error compiling shader: {s}\n", .{msg}) catch {};
        return LoadError.CompileShaderFailed;
    }

    return Self{ .handle = shader };
}

pub fn deinit(self: Self) void {
    c.glDeleteShader(self.handle);
}