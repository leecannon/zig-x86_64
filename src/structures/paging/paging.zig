pub usingnamespace @import("page_table.zig");
pub usingnamespace @import("frame.zig");
pub usingnamespace @import("page.zig");
pub usingnamespace @import("frame_alloc.zig");

pub usingnamespace @import("mapper/mapper.zig");

test "" {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
