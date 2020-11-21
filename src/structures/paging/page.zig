usingnamespace @import("../../common.zig");

const PageTableIndex = structures.paging.PageTableIndex;

const size4KiBStr: []const u8 = "4KiB";
const size2MiBStr: []const u8 = "2MiB";
const size1GiBStr: []const u8 = "1GiB";

pub const PageSize = enum {
    Size4KiB,
    Size2MiB,
    Size1GiB,

    pub fn Size(self: PageSize) u64 {
        return switch (self) {
            .Size4KiB => 4096,
            .Size2MiB => 4096 * 512,
            .Size1GiB => 4096 * 512 * 512,
        };
    }

    pub fn SizeString(self: PageSize) []const u8 {
        return switch (self) {
            .Size4KiB => size4KiBStr,
            .Size2MiB => size2MiBStr,
            .Size1GiB => size1GiBStr,
        };
    }

    pub fn IsGiantPage(self: PageSize) bool {
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
    const physFrameType = switch (page_size) {
        .Size4KiB => structures.paging.PhysFrame,
        .Size2MiB => structures.paging.PhysFrame2MiB,
        .Size1GiB => structures.paging.PhysFrame1GiB,
    };

    return struct {
        const Self = @This();
        const Size: u64 = page_size.Size();

        start_address: VirtAddr,

        /// Returns the page that starts at the given virtual address.
        ///
        /// Returns an error if the address is not correctly aligned (i.e. is not a valid page start).
        pub fn from_start_address(address: VirtAddr) PageError!Self {
            if (!address.is_aligned(page_size.Size())) {
                return PageError.AddressNotAligned;
            }
            return containing_address(address);
        }

        /// Returns the page that starts at the given virtual address.
        pub fn from_start_address_unchecked(address: VirtAddr) Self {
            return Self{ .start_address = address };
        }

        /// Returns the page that contains the given virtual address.
        pub fn containing_address(address: VirtAddr) Self {
            return Self{ .start_address = address.align_down(page_size.Size()) };
        }

        /// Returns the level 4 page table index of this page.
        pub fn p4_index(self: Self) PageTableIndex {
            return self.start_address.p4_index();
        }

        /// Returns the level 3 page table index of this page.
        pub fn p3_index(self: Self) PageTableIndex {
            return self.start_address.p3_index();
        }

        /// Returns the level 2 page table index of this page.
        /// Not usable for Size1GiB
        pub fn p2_index(self: Self) PageTableIndex {
            comptime {
                if (page_size == .Size1GiB) {
                    @compileError("Not usable for Size1GiB");
                }
            }
            return self.start_address.p2_index();
        }

        /// Returns the level 1 page table index of this page.
        /// Only usable for Size4KiB
        pub fn p1_index(self: Self) PageTableIndex {
            comptime {
                if (page_size != .Size4KiB) {
                    @compileError("Only usable for Size4KiB");
                }
            }
            return self.start_address.p1_index();
        }

        pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.writeAll("Frame[" ++ page_size.SizeString() ++ "](0x");

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
pub fn page_from_table_indices_1gib(p4_index: PageTableIndex, p3_index: PageTableIndex) Page1GiB {
    var addr: u64 = 0;
    set_bits(&addr, 39, 9, @as(u64, p4_index.value));
    set_bits(&addr, 30, 9, @as(u64, p3_index.value));
    return Page1GiB.containing_address(VirtAddr.init(addr));
}

/// Returns the 2MiB memory page with the specified page table indices.
pub fn page_from_table_indices_2mib(p4_index: PageTableIndex, p3_index: PageTableIndex, p2_index: PageTableIndex) Page2MiB {
    var addr: u64 = 0;
    set_bits(&addr, 39, 9, @as(u64, p4_index.value));
    set_bits(&addr, 30, 9, @as(u64, p3_index.value));
    set_bits(&addr, 21, 9, @as(u64, p2_index.value));
    return Page2MiB.containing_address(VirtAddr.init(addr));
}

/// Returns the 4KiB memory page with the specified page table indices.
pub fn page_from_table_indices_4kib(p4_index: PageTableIndex, p3_index: PageTableIndex, p2_index: PageTableIndex, p1_index: PageTableIndex) Page {
    var addr: u64 = 0;
    set_bits(&addr, 39, 9, @as(u64, p4_index.value));
    set_bits(&addr, 30, 9, @as(u64, p3_index.value));
    set_bits(&addr, 21, 9, @as(u64, p2_index.value));
    set_bits(&addr, 12, 9, @as(u64, p1_index.value));
    return Page.containing_address(VirtAddr.init(addr));
}

/// Generates iterators for ranges of physical memory frame. Page size 4 KiB
pub const PageIterator = CreatePageIterator(Page);

/// Generates iterators for ranges of physical memory frame. Page size 2 MiB
pub const PageIterator2MiB = CreatePageIterator(Page2MiB);

/// Generates iterators for ranges of physical memory frame. Page size 1 GiB
pub const PageIterator1GiB = CreatePageIterator(Page1GiB);

fn CreatePageIterator(comptime page_type: type) type {
    const pageRangeType = switch (page_type) {
        Page => PageRange,
        Page2MiB => PageRange2MiB,
        Page1GiB => PageRange1GiB,
        else => @compileError("Non-Page type given"),
    };

    const pageRangeInclusiveType = switch (page_type) {
        Page => PageRangeInclusive,
        Page2MiB => PageRange2MiBInclusive,
        Page1GiB => PageRange1GiBInclusive,
        else => @compileError("Non-Page type given"),
    };

    return struct {
        /// Returns a range of pages, exclusive `end`.
        pub fn range(start: page_type, end: page_type) pageRangeType {
            return pageRangeType{ .start = start, .end = end };
        }

        /// Returns a range of pages, inclusive `end`.
        pub fn range_inclusive(start: page_type, end: page_type) pageRangeInclusiveType {
            return pageRangeInclusiveType{ .start = start, .end = end };
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
        pub fn is_empty(self: Self) bool {
            return self.start.start_address.value >= self.end.start_address.value;
        }

        pub fn next(self: *Self) ?page_type {
            if (self.start.start_address.value < self.end.start_address.value) {
                const page = self.start;
                self.start = page_type.containing_address(VirtAddr{ .value = self.start.start_address.value + page_type.Size });
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
        pub fn is_empty(self: Self) bool {
            return self.start.start_address.value > self.end.start_address.value;
        }

        pub fn next(self: *Self) ?page_type {
            if (self.start.start_address.value <= self.end.start_address.value) {
                const page = self.start;
                self.start = page_type.containing_address(VirtAddr{ .value = self.start.start_address.value + page_type.Size });
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
    virtAddrA = virtAddrA.align_down(structures.paging.PageSize.Size4KiB.Size());

    var virtAddrB = VirtAddr.init(0x00000FFFFFFFFFFF);
    virtAddrB = virtAddrB.align_down(structures.paging.PageSize.Size4KiB.Size());

    const a = try Page.from_start_address(virtAddrA);
    const b = try Page.from_start_address(virtAddrB);

    var iterator = PageIterator.range(a, b);
    var inclusive_iterator = PageIterator.range_inclusive(a, b);

    std.testing.expect(!iterator.is_empty());
    std.testing.expect(!inclusive_iterator.is_empty());

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

    std.testing.expect(iterator.is_empty());
    std.testing.expect(inclusive_iterator.is_empty());
}

test "" {
    std.testing.refAllDecls(@This());
}
