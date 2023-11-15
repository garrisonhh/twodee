//! simple abstraction for loading a shared object

const std = @import("std");

const Self = @This();

pub const OpenError = error {SoOpenFailed};
pub const SymbolError = error {SoSymbolNotFound};
pub const Error = OpenError || SymbolError;

handle: *anyopaque,

pub fn open(path: [:0]const u8) OpenError!Self {
    const handle = std.c.dlopen(path.ptr, std.c.RTLD.LAZY) orelse {
        return OpenError.SoOpenFailed;
    };

    return .{ .handle = handle };
}

pub fn close(self: Self) void {
    _ = std.c.dlclose(self.handle);
}

/// retrieve a symbol
pub fn symbol(
    self: Self,
    name: [:0]const u8,
    comptime T: type,
) SymbolError!*const T {
    const ptr = std.c.dlsym(self.handle, name.ptr) orelse {
        return SymbolError.SoSymbolNotFound;
    };

    return @ptrCast(@alignCast(ptr));
}