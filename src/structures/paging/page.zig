usingnamespace @import("../../common.zig");

const size4KiBStr: []const u8 = "4KiB";
const size2MiBStr: []const u8 = "2MiB";
const size1GiBStr: []const u8 = "1GiB";

pub const PageSize = enum {
    Size4KiB,
    Size2MiB,
    Size1GiB,

    pub inline fn Size(self: PageSize) u64 {
        return switch (self) {
            .Size4KiB => 4096,
            .Size2MiB => 4096 * 512,
            .Size1GiB => 4096 * 512 * 512,
        };
    }

    pub inline fn SizeString(self: PageSize) []const u8 {
        return switch (self) {
            .Size4KiB => size4KiBStr,
            .Size2MiB => size2MiBStr,
            .Size1GiB => size1GiBStr,
        };
    }

    pub inline fn IsGiantPage(self: PageSize) bool {
        return self == .Size1GiB;
    }
};
