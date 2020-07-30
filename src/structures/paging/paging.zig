pub usingnamespace @import("page_table.zig");
pub usingnamespace @import("page.zig");
pub usingnamespace @import("frame.zig");

test "" {
    const std = @import("std");
    std.meta.refAllDecls(@This());
}
