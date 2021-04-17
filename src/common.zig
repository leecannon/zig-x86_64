pub const x86_64 = @import("index.zig");
pub usingnamespace @import("bits.zig");

pub const std = @import("std");

comptime {
    std.testing.refAllDecls(@This());
}
