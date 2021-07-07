usingnamespace @import("../../common.zig");

const PageTableIndex = x86_64.structures.paging.PageTableIndex;

const SIZE_4KiB_STR: []const u8 = "4KiB";
const SIZE_2MiB_STR: []const u8 = "2MiB";
const SIZE_1GiB_STR: []const u8 = "1GiB";

pub const PageSize = enum {
    Size4KiB,
    Size2MiB,
    Size1GiB,

    pub fn bytes(self: PageSize) u64 {
        return switch (self) {
            .Size4KiB => 4096,
            .Size2MiB => 4096 * 512,
            .Size1GiB => 4096 * 512 * 512,
        };
    }

    pub fn sizeString(self: PageSize) []const u8 {
        return switch (self) {
            .Size4KiB => SIZE_4KiB_STR,
            .Size2MiB => SIZE_2MiB_STR,
            .Size1GiB => SIZE_1GiB_STR,
        };
    }

    pub fn isGiantPage(self: PageSize) bool {
        return self == .Size1GiB;
    }
};

/// A virtual memory page. Page size 4 KiB
pub const Page = extern struct {
    const page_size = PageSize.Size4KiB;
    const bytes: u64 = page_size.bytes();

    start_address: x86_64.VirtAddr,

    /// Returns the page that starts at the given virtual address.
    ///
    /// Returns an error if the address is not correctly aligned (i.e. is not a valid page start).
    pub fn fromStartAddress(address: x86_64.VirtAddr) PageError!Page {
        if (!address.isAligned(page_size.bytes())) {
            return PageError.AddressNotAligned;
        }
        return containingAddress(address);
    }

    /// Returns the page that starts at the given virtual address.
    pub fn fromStartAddressUnchecked(address: x86_64.VirtAddr) Page {
        return .{ .start_address = address };
    }

    /// Returns the page that contains the given virtual address.
    pub fn containingAddress(address: x86_64.VirtAddr) Page {
        return .{ .start_address = address.alignDown(page_size.bytes()) };
    }

    /// Returns the level 4 page table index of this page.
    pub fn p4Index(self: Page) PageTableIndex {
        return self.start_address.p4Index();
    }

    /// Returns the level 3 page table index of this page.
    pub fn p3Index(self: Page) PageTableIndex {
        return self.start_address.p3Index();
    }

    /// Returns the level 2 page table index of this page.
    pub fn p2Index(self: Page) PageTableIndex {
        return self.start_address.p2Index();
    }

    /// Returns the level 1 page table index of this page.
    pub fn p1Index(self: Page) PageTableIndex {
        return self.start_address.p1Index();
    }

    pub fn format(value: Page, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;
        _ = fmt;
        try writer.print("Page[" ++ page_size.sizeString() ++ "](0x{x})", .{value.start_address.value});
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A virtual memory page. Page size 2 MiB
pub const Page2MiB = extern struct {
    const page_size = PageSize.Size2MiB;
    const bytes: u64 = page_size.bytes();

    start_address: x86_64.VirtAddr,

    /// Returns the page that starts at the given virtual address.
    ///
    /// Returns an error if the address is not correctly aligned (i.e. is not a valid page start).
    pub fn fromStartAddress(address: x86_64.VirtAddr) PageError!Page2MiB {
        if (!address.isAligned(page_size.bytes())) {
            return PageError.AddressNotAligned;
        }
        return containingAddress(address);
    }

    /// Returns the page that starts at the given virtual address.
    pub fn fromStartAddressUnchecked(address: x86_64.VirtAddr) Page2MiB {
        return .{ .start_address = address };
    }

    /// Returns the page that contains the given virtual address.
    pub fn containingAddress(address: x86_64.VirtAddr) Page2MiB {
        return .{ .start_address = address.alignDown(page_size.bytes()) };
    }

    /// Returns the level 4 page table index of this page.
    pub fn p4Index(self: Page2MiB) PageTableIndex {
        return self.start_address.p4Index();
    }

    /// Returns the level 3 page table index of this page.
    pub fn p3Index(self: Page2MiB) PageTableIndex {
        return self.start_address.p3Index();
    }

    /// Returns the level 2 page table index of this page.
    pub fn p2Index(self: Page2MiB) PageTableIndex {
        return self.start_address.p2Index();
    }

    pub fn format(value: Page2MiB, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;
        _ = fmt;
        try writer.print("Page[" ++ page_size.sizeString() ++ "](0x{x})", .{value.start_address.value});
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A virtual memory page. Page size 1 GiB
pub const Page1GiB = extern struct {
    const page_size = PageSize.Size1GiB;
    const bytes: u64 = page_size.bytes();

    start_address: x86_64.VirtAddr,

    /// Returns the page that starts at the given virtual address.
    ///
    /// Returns an error if the address is not correctly aligned (i.e. is not a valid page start).
    pub fn fromStartAddress(address: x86_64.VirtAddr) PageError!Page1GiB {
        if (!address.isAligned(page_size.bytes())) {
            return PageError.AddressNotAligned;
        }
        return containingAddress(address);
    }

    /// Returns the page that starts at the given virtual address.
    pub fn fromStartAddressUnchecked(address: x86_64.VirtAddr) Page1GiB {
        return .{ .start_address = address };
    }

    /// Returns the page that contains the given virtual address.
    pub fn containingAddress(address: x86_64.VirtAddr) Page1GiB {
        return .{ .start_address = address.alignDown(page_size.bytes()) };
    }

    /// Returns the level 4 page table index of this page.
    pub fn p4Index(self: Page1GiB) PageTableIndex {
        return self.start_address.p4Index();
    }

    /// Returns the level 3 page table index of this page.
    pub fn p3Index(self: Page1GiB) PageTableIndex {
        return self.start_address.p3Index();
    }

    pub fn format(value: Page1GiB, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;
        _ = fmt;
        try writer.print("Page[" ++ page_size.sizeString() ++ "](0x{x})", .{value.start_address.value});
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const PageError = error{AddressNotAligned};

/// Returns the 1GiB memory page with the specified page table indices.
pub fn pageFromTableIndices1GiB(p4_index: PageTableIndex, p3_index: PageTableIndex) Page1GiB {
    var addr: u64 = 0;
    bitjuggle.setBits(&addr, 39, 9, p4_index.value);
    bitjuggle.setBits(&addr, 30, 9, p3_index.value);
    return Page1GiB.containingAddress(x86_64.VirtAddr.initPanic(addr));
}

/// Returns the 2MiB memory page with the specified page table indices.
pub fn pageFromTableIndices2MiB(p4_index: PageTableIndex, p3_index: PageTableIndex, p2_index: PageTableIndex) Page2MiB {
    var addr: u64 = 0;
    bitjuggle.setBits(&addr, 39, 9, p4_index.value);
    bitjuggle.setBits(&addr, 30, 9, p3_index.value);
    bitjuggle.setBits(&addr, 21, 9, p2_index.value);
    return Page2MiB.containingAddress(x86_64.VirtAddr.initPanic(addr));
}

/// Returns the 4KiB memory page p4_index the specified page table indices.
pub fn pageFromTableIndices(p4_index: PageTableIndex, p3_index: PageTableIndex, p2_index: PageTableIndex, p1_index: PageTableIndex) Page {
    var addr: u64 = 0;
    bitjuggle.setBits(&addr, 39, 9, p4_index.value);
    bitjuggle.setBits(&addr, 30, 9, p3_index.value);
    bitjuggle.setBits(&addr, 21, 9, p2_index.value);
    bitjuggle.setBits(&addr, 12, 9, p1_index.value);
    return Page.containingAddress(x86_64.VirtAddr.initPanic(addr));
}

/// A range of pages, exclusive the upper bound. Page size 4 KiB
pub const PageRange = struct {
    /// The start of the range, inclusive.
    start: Page,
    /// The end of the range, exclusive.
    end: Page,

    /// Returns whether the range contains no frames.
    pub fn isEmpty(self: PageRange) bool {
        return self.start.start_address.value >= self.end.start_address.value;
    }

    pub fn next(self: *PageRange) ?Page {
        if (self.start.start_address.value < self.end.start_address.value) {
            const page = self.start;
            self.start = Page.containingAddress(.{ .value = self.start.start_address.value + Page.bytes });
            return page;
        }
        return null;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A range of pages, exclusive the upper bound. Page size 2 MiB
pub const PageRange2MiB = struct {
    /// The start of the range, inclusive.
    start: Page2MiB,
    /// The end of the range, exclusive.
    end: Page2MiB,

    /// Returns whether the range contains no frames.
    pub fn isEmpty(self: PageRange2MiB) bool {
        return self.start.start_address.value >= self.end.start_address.value;
    }

    pub fn next(self: *PageRange2MiB) ?Page2MiB {
        if (self.start.start_address.value < self.end.start_address.value) {
            const page = self.start;
            self.start = Page2MiB.containingAddress(.{ .value = self.start.start_address.value + Page2MiB.bytes });
            return page;
        }
        return null;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A range of pages, exclusive the upper bound. Page size 1 GiB
pub const PageRange1GiB = struct {
    /// The start of the range, inclusive.
    start: Page1GiB,
    /// The end of the range, exclusive.
    end: Page1GiB,

    /// Returns whether the range contains no frames.
    pub fn isEmpty(self: PageRange1GiB) bool {
        return self.start.start_address.value >= self.end.start_address.value;
    }

    pub fn next(self: *PageRange1GiB) ?Page1GiB {
        if (self.start.start_address.value < self.end.start_address.value) {
            const page = self.start;
            self.start = Page1GiB.containingAddress(.{ .value = self.start.start_address.value + Page1GiB.bytes });
            return page;
        }
        return null;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A range of pages, inclusive the upper bound. Page size 4 KiB
pub const PageRangeInclusive = struct {
    /// The start of the range, inclusive.
    start: Page,
    /// The end of the range, exclusive.
    end: Page,

    /// Returns whether the range contains no frames.
    pub fn isEmpty(self: PageRangeInclusive) bool {
        return self.start.start_address.value > self.end.start_address.value;
    }

    pub fn next(self: *PageRangeInclusive) ?Page {
        if (self.start.start_address.value <= self.end.start_address.value) {
            const page = self.start;
            self.start = Page.containingAddress(x86_64.VirtAddr{ .value = self.start.start_address.value + Page.bytes });
            return page;
        }
        return null;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A range of pages, inclusive the upper bound. Page size 2 MiB
pub const PageRange2MiBInclusive = struct {
    /// The start of the range, inclusive.
    start: Page2MiB,
    /// The end of the range, exclusive.
    end: Page2MiB,

    /// Returns whether the range contains no frames.
    pub fn isEmpty(self: PageRange2MiBInclusive) bool {
        return self.start.start_address.value > self.end.start_address.value;
    }

    pub fn next(self: *PageRange2MiBInclusive) ?Page2MiB {
        if (self.start.start_address.value <= self.end.start_address.value) {
            const page = self.start;
            self.start = Page2MiB.containingAddress(x86_64.VirtAddr{ .value = self.start.start_address.value + Page2MiB.bytes });
            return page;
        }
        return null;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A range of pages, inclusive the upper bound. Page size 1 GiB
pub const PageRange1GiBInclusive = struct {
    /// The start of the range, inclusive.
    start: Page1GiB,
    /// The end of the range, exclusive.
    end: Page1GiB,

    /// Returns whether the range contains no frames.
    pub fn isEmpty(self: PageRange1GiBInclusive) bool {
        return self.start.start_address.value > self.end.start_address.value;
    }

    pub fn next(self: *PageRange1GiBInclusive) ?Page1GiB {
        if (self.start.start_address.value <= self.end.start_address.value) {
            const page = self.start;
            self.start = Page1GiB.containingAddress(x86_64.VirtAddr{ .value = self.start.start_address.value + Page1GiB.bytes });
            return page;
        }
        return null;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Generates iterators for ranges of physical memory frame. Page size 4 KiB
pub const PageIterator = struct {
    /// Returns a range of pages, exclusive `end`.
    pub fn range(start: Page, end: Page) PageRange {
        return .{ .start = start, .end = end };
    }

    /// Returns a range of pages, inclusive `end`.
    pub fn rangeInclusive(start: Page, end: Page) PageRangeInclusive {
        return .{ .start = start, .end = end };
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Generates iterators for ranges of physical memory frame. Page size 2 MiB
pub const PageIterator2MiB = struct {
    /// Returns a range of pages, exclusive `end`.
    pub fn range(start: Page2MiB, end: Page2MiB) PageRange2MiB {
        return .{ .start = start, .end = end };
    }

    /// Returns a range of pages, inclusive `end`.
    pub fn rangeInclusive(start: Page2MiB, end: Page2MiB) PageRange2MiBInclusive {
        return .{ .start = start, .end = end };
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Generates iterators for ranges of physical memory frame. Page size 1 GiB
pub const PageIterator1GiB = struct {
    /// Returns a range of pages, exclusive `end`.
    pub fn range(start: Page1GiB, end: Page1GiB) PageRange1GiB {
        return .{ .start = start, .end = end };
    }

    /// Returns a range of pages, inclusive `end`.
    pub fn rangeInclusive(start: Page1GiB, end: Page1GiB) PageRange1GiBInclusive {
        return .{ .start = start, .end = end };
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

test "PageIterator" {
    var virtAddrA = x86_64.VirtAddr.initPanic(0x00000FFFFFFF0000);
    virtAddrA = virtAddrA.alignDown(x86_64.structures.paging.PageSize.Size4KiB.bytes());

    var virtAddrB = x86_64.VirtAddr.initPanic(0x00000FFFFFFFFFFF);
    virtAddrB = virtAddrB.alignDown(x86_64.structures.paging.PageSize.Size4KiB.bytes());

    const a = try Page.fromStartAddress(virtAddrA);
    const b = try Page.fromStartAddress(virtAddrB);

    var iterator = PageIterator.range(a, b);
    var inclusive_iterator = PageIterator.rangeInclusive(a, b);

    try std.testing.expect(!iterator.isEmpty());
    try std.testing.expect(!inclusive_iterator.isEmpty());

    var count: usize = 0;
    while (iterator.next()) |_| {
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 15), count);

    count = 0;
    while (inclusive_iterator.next()) |_| {
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 16), count);

    try std.testing.expect(iterator.isEmpty());
    try std.testing.expect(inclusive_iterator.isEmpty());
}

comptime {
    std.testing.refAllDecls(@This());
}
