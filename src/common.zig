pub const x86_64 = @import("index.zig");
pub usingnamespace @import("bits.zig");

pub const std = @import("std");

pub fn formatWithoutFields(value: anytype, options: std.fmt.FormatOptions, writer: anytype, comptime blacklist: []const []const u8) !void {
    // This ANY const is a workaround for: https://github.com/ziglang/zig/issues/7948
    const ANY = "any";

    const T = @TypeOf(value);

    switch (@typeInfo(T)) {
        .Struct => |info| {
            try writer.writeAll(@typeName(T));
            try writer.writeAll("{");
            comptime var i = 0;
            outer: inline for (info.fields) |f| {
                inline for (blacklist) |blacklist_item| {
                    if (comptime std.mem.indexOf(u8, f.name, blacklist_item) != null) continue :outer;
                }

                if (i == 0) {
                    try writer.writeAll(" .");
                } else {
                    try writer.writeAll(", .");
                }

                try writer.writeAll(f.name);
                try writer.writeAll(" = ");
                try std.fmt.formatType(@field(value, f.name), ANY, options, writer, std.fmt.default_max_depth - 1);

                i += 1;
            }
            try writer.writeAll(" }");
        },
        else => {
            @compileError("Unimplemented for: " ++ @typeName(T));
        },
    }
}

comptime {
    std.testing.refAllDecls(@This());
}
