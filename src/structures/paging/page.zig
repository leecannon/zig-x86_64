usingnamespace @import("../../common.zig");

const PageTableIndex = structures.paging.PageTableIndex;

const SIZE_4KiB_STR: []const u8 = "4KiB";
const SIZE_2MiB_STR: []const u8 = "2MiB";
const SIZE_1GiB_STR: []const u8 = "1GiB";

pub const PageSize = enum {
    Size4KiB,
    Size2MiB,
    Size1GiB,

    pub inline fn bytes(self: PageSize) u64 {
        return switch (self) {
            .Size4KiB => 4096,
            .Size2MiB => 4096 * 512,
            .Size1GiB => 4096 * 512 * 512,
        };
    }

    pub inline fn sizeString(self: PageSize) []const u8 {
        return switch (self) {
            .Size4KiB => SIZE_4KiB_STR,
            .Size2MiB => SIZE_2MiB_STR,
            .Size1GiB => SIZE_1GiB_STR,
        };
    }

    pub inline fn isGiantPage(self: PageSize) bool {
        return self == .Size1GiB;
    }
};

/// A virtual memory page. Page size 4 KiB
pub const Page = CreatePage(structures.paging.PageSize.Size4KiB);

/// A virtual memory page. Page size 2 MiB
pub const Page2MiB = CreatePage(structures.paging.PageSize.Size2MiB);

/// A virtual memory page. Page size 1 GiB
pub const Page1GiB = CreatePage(structures.paging.PageSize.Size1GiB);

pub const PageError = error{AddressNotAligned};

fn CreatePage(comptime page_size: PageSize) type {
    const phys_frame_type = switch (page_size) {
        .Size4KiB => structures.paging.PhysFrame,
        .Size2MiB => structures.paging.PhysFrame2MiB,
        .Size1GiB => structures.paging.PhysFrame1GiB,
    };

    return struct {
        const Self = @This();
        const bytes: u64 = page_size.bytes();

        start_address: VirtAddr,

        /// Returns the page that starts at the given virtual address.
        ///
        /// Returns an error if the address is not correctly aligned (i.e. is not a valid page start).
        pub inline fn fromStartAddress(address: VirtAddr) PageError!Self {
            if (!address.isAligned(page_size.bytes())) {
                return PageError.AddressNotAligned;
            }
            return containingAddress(address);
        }

        /// Returns the page that starts at the given virtual address.
        pub inline fn fromStartAddressUnchecked(address: VirtAddr) Self {
            return Self{ .start_address = address };
        }

        /// Returns the page that contains the given virtual address.
        pub inline fn containingAddress(address: VirtAddr) Self {
            return Self{ .start_address = address.alignDown(page_size.bytes()) };
        }

        /// Returns the level 4 page table index of this page.
        pub inline fn getP4Index(self: Self) PageTableIndex {
            return self.start_address.getP4Index();
        }

        /// Returns the level 3 page table index of this page.
        pub inline fn getP3Index(self: Self) PageTableIndex {
            return self.start_address.getP3Index();
        }

        /// Returns the level 2 page table index of this page.
        /// Not usable for Size1GiB
        pub inline fn getP2Index(self: Self) PageTableIndex {
            comptime {
                if (page_size == .Size1GiB) {
                    @compileError("Not usable for Size1GiB");
                }
            }
            return self.start_address.getP2Index();
        }

        /// Returns the level 1 page table index of this page.
        /// Only usable for Size4KiB
        pub inline fn getP1Index(self: Self) PageTableIndex {
            comptime {
                if (page_size != .Size4KiB) {
                    @compileError("Only usable for Size4KiB");
                }
            }
            return self.start_address.getP1Index();
        }

        pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.writeAll("Frame[" ++ page_size.sizeString() ++ "](0x");

            try std.fmt.formatType(
                value.start_address.value,
                "x",
                .{},
                writer,
                1,
            );

            try writer.writeAll(")");
        }
    };
}

/// Returns the 1GiB memory page with the specified page table indices.
pub fn pageFromTableIndices1gib(getP4Index: PageTableIndex, getP3Index: PageTableIndex) Page1GiB {
    var addr: u64 = 0;
    setBits(&addr, 39, 9, @as(u64, getP4Index.value));
    setBits(&addr, 30, 9, @as(u64, getP3Index.value));
    return Page1GiB.containingAddress(VirtAddr.init(addr));
}

/// Returns the 2MiB memory page with the specified page table indices.
pub fn pageFromTableIndices2mib(getP4Index: PageTableIndex, getP3Index: PageTableIndex, getP2Index: PageTableIndex) Page2MiB {
    var addr: u64 = 0;
    setBits(&addr, 39, 9, @as(u64, getP4Index.value));
    setBits(&addr, 30, 9, @as(u64, getP3Index.value));
    setBits(&addr, 21, 9, @as(u64, getP2Index.value));
    return Page2MiB.containingAddress(VirtAddr.init(addr));
}

/// Returns the 4KiB memory page with the specified page table indices.
pub fn pageFromTableIndices4kib(getP4Index: PageTableIndex, getP3Index: PageTableIndex, getP2Index: PageTableIndex, getP1Index: PageTableIndex) Page {
    var addr: u64 = 0;
    setBits(&addr, 39, 9, @as(u64, getP4Index.value));
    setBits(&addr, 30, 9, @as(u64, getP3Index.value));
    setBits(&addr, 21, 9, @as(u64, getP2Index.value));
    setBits(&addr, 12, 9, @as(u64, getP1Index.value));
    return Page.containingAddress(VirtAddr.init(addr));
}

/// Generates iterators for ranges of physical memory frame. Page size 4 KiB
pub const PageIterator = CreatePageIterator(Page);

/// Generates iterators for ranges of physical memory frame. Page size 2 MiB
pub const PageIterator2MiB = CreatePageIterator(Page2MiB);

/// Generates iterators for ranges of physical memory frame. Page size 1 GiB
pub const PageIterator1GiB = CreatePageIterator(Page1GiB);

fn CreatePageIterator(comptime page_type: type) type {
    const page_range_type = switch (page_type) {
        Page => PageRange,
        Page2MiB => PageRange2MiB,
        Page1GiB => PageRange1GiB,
        else => @compileError("Non-Page type given"),
    };

    const page_range_inclusive_type = switch (page_type) {
        Page => PageRangeInclusive,
        Page2MiB => PageRange2MiBInclusive,
        Page1GiB => PageRange1GiBInclusive,
        else => @compileError("Non-Page type given"),
    };

    return struct {
        /// Returns a range of pages, exclusive `end`.
        pub inline fn range(start: page_type, end: page_type) page_range_type {
            return page_range_type{ .start = start, .end = end };
        }

        /// Returns a range of pages, inclusive `end`.
        pub inline fn rangeInclusive(start: page_type, end: page_type) page_range_inclusive_type {
            return page_range_inclusive_type{ .start = start, .end = end };
        }

        test "" {
            std.testing.refAllDecls(@This());
        }
    };
}

/// An range of pages, exclusive the upper bound. Page size 4 KiB
pub const PageRange = CreatePageRange(Page);

/// An range of pages, exclusive the upper bound. Page size 2 MiB
pub const PageRange2MiB = CreatePageRange(Page2MiB);

/// An range of pages, exclusive the upper bound. Page size 1 GiB
pub const PageRange1GiB = CreatePageRange(Page1GiB);

fn CreatePageRange(comptime page_type: type) type {
    comptime {
        if (page_type != Page and page_type != Page2MiB and page_type != Page1GiB) {
            @compileError("Non-Page type given");
        }
    }

    return struct {
        const Self = @This();

        /// The start of the range, inclusive.
        start: page_type,
        /// The end of the range, exclusive.
        end: page_type,

        /// Returns whether the range contains no frames.
        pub inline fn isEmpty(self: Self) bool {
            return self.start.start_address.value >= self.end.start_address.value;
        }

        pub fn next(self: *Self) ?page_type {
            if (self.start.start_address.value < self.end.start_address.value) {
                const page = self.start;
                self.start = page_type.containingAddress(VirtAddr{ .value = self.start.start_address.value + page_type.bytes });
                return page;
            }
            return null;
        }

        test "" {
            std.testing.refAllDecls(@This());
        }
    };
}

/// An range of pages, inclusive the upper bound. Page size 4 KiB
pub const PageRangeInclusive = CreatePageRangeInclusive(Page);

/// An range of pages, inclusive the upper bound. Page size 2 MiB
pub const PageRange2MiBInclusive = CreatePageRangeInclusive(Page2MiB);

/// An range of pages, inclusive the upper bound. Page size 1 GiB
pub const PageRange1GiBInclusive = CreatePageRangeInclusive(Page1GiB);

fn CreatePageRangeInclusive(comptime page_type: type) type {
    comptime {
        if (page_type != Page and page_type != Page2MiB and page_type != Page1GiB) {
            @compileError("Non-Page type given");
        }
    }

    return struct {
        const Self = @This();

        /// The start of the range, inclusive.
        start: page_type,
        /// The end of the range, exclusive.
        end: page_type,

        /// Returns whether the range contains no frames.
        pub inline fn isEmpty(self: Self) bool {
            return self.start.start_address.value > self.end.start_address.value;
        }

        pub fn next(self: *Self) ?page_type {
            if (self.start.start_address.value <= self.end.start_address.value) {
                const page = self.start;
                self.start = page_type.containingAddress(VirtAddr{ .value = self.start.start_address.value + page_type.bytes });
                return page;
            }
            return null;
        }

        test "" {
            std.testing.refAllDecls(@This());
        }
    };
}

test "PageIterator" {
    var virtAddrA = VirtAddr.init(0x00000FFFFFFF0000);
    virtAddrA = virtAddrA.alignDown(structures.paging.PageSize.Size4KiB.bytes());

    var virtAddrB = VirtAddr.init(0x00000FFFFFFFFFFF);
    virtAddrB = virtAddrB.alignDown(structures.paging.PageSize.Size4KiB.bytes());

    const a = try Page.fromStartAddress(virtAddrA);
    const b = try Page.fromStartAddress(virtAddrB);

    var iterator = PageIterator.range(a, b);
    var inclusive_iterator = PageIterator.rangeInclusive(a, b);

    std.testing.expect(!iterator.isEmpty());
    std.testing.expect(!inclusive_iterator.isEmpty());

    var count: usize = 0;
    while (iterator.next()) |frame| {
        count += 1;
    }
    testing.expectEqual(@as(usize, 15), count);

    count = 0;
    while (inclusive_iterator.next()) |frame| {
        count += 1;
    }
    testing.expectEqual(@as(usize, 16), count);

    std.testing.expect(iterator.isEmpty());
    std.testing.expect(inclusive_iterator.isEmpty());
}

test "" {
    std.testing.refAllDecls(@This());
}
