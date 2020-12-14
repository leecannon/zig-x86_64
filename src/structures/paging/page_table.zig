usingnamespace @import("../../common.zig");

const PageSize = structures.paging.PageSize;

/// The error returned by the `PageTableEntry::frame` method.
pub const FrameError = error{
    /// The entry does not have the `present` flag set, so it isn't currently mapped to a frame.
    FrameNotPresent,
    /// The entry does have the `huge_page` flag set. The `frame` method has a standard 4KiB frame
    /// as return type, so a huge frame can't be returned.
    HugeFrame,
};

/// A 64-bit page table entry.
pub const PageTableEntry = packed struct {
    entry: u64,

    /// Creates an unused page table entry.
    pub inline fn init() PageTableEntry {
        return PageTableEntry{ .entry = 0 };
    }

    /// Returns whether this entry is zero.
    pub inline fn isUnused(self: PageTableEntry) bool {
        return self.entry == 0;
    }

    /// Sets this entry to zero.
    pub inline fn setUnused(self: *PageTableEntry) void {
        self.entry = 0;
    }

    /// Returns the flags of this entry.
    pub fn getFlags(self: PageTableEntry) PageTableFlags {
        // Clear out the addr part of the entry
        var entry = self.entry;
        setBits(&entry, 12, 40, 0);
        return PageTableFlags.fromU64(entry);
    }

    /// Returns the physical address mapped by this entry, might be zero.
    pub inline fn getAddr(self: PageTableEntry) PhysAddr {
        return PhysAddr.init(self.entry & 0x000fffff_fffff000);
    }

    /// Returns the physical frame mapped by this entry.
    ///
    /// Returns the following errors:
    ///
    /// - `FrameError::FrameNotPresent` if the entry doesn't have the `present` flag set.
    /// - `FrameError::HugeFrame` if the entry has the `huge_page` flag set (for huge pages the
    ///    `addr` function must be used)
    pub fn getFrame(self: PageTableEntry) FrameError!structures.paging.PhysFrame {
        const flags = self.getFlags();

        if (!flags.present) {
            return FrameError.FrameNotPresent;
        }

        if (flags.huge_page) {
            return FrameError.HugeFrame;
        }

        return structures.paging.PhysFrame.containingAddress(self.getAddr());
    }

    /// Map the entry to the specified physical address
    pub inline fn setAddr(self: *PageTableEntry, addr: PhysAddr) void {
        std.debug.assert(addr.isAligned(PageSize.Size4KiB.bytes()));
        self.entry = addr.value | self.getFlags().toU64();
    }

    /// Map the entry to the specified physical frame with the specified flags.
    pub inline fn setFrame(self: *PageTableEntry, frame: structures.paging.PhysFrame, flags: PageTableFlags) void {
        std.debug.assert(!self.getFlags().huge_page);
        self.setAddr(frame.start_address);
        self.setFlags(flags);
    }

    /// Sets the flags of this entry.
    pub inline fn setFlags(self: *PageTableEntry, flags: PageTableFlags) void {
        self.entry = self.getAddr().value | flags.toU64();
    }

    pub fn format(value: PageTableEntry, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("PageTableEntry(Addr = {x}, Flags = {})", .{ value.getAddr(), value.getFlags() });
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "PageTableEntry" {
    std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(PageTableEntry));
    std.testing.expectEqual(@sizeOf(u64), @sizeOf(PageTableEntry));

    var a = PageTableEntry.init();

    var addr = PhysAddr.init(0x000fffff_ffff2000);
    var flags = PageTableFlags.init();

    a.setAddr(addr);
    a.setFlags(flags);

    testing.expectEqual(@as(u64, 0x000fffff_ffff2000), a.getAddr().value);
    testing.expectEqual(@as(u64, 0), a.getFlags().toU64());

    flags.present = true;
    testing.expectEqual(@as(u64, 0), a.getFlags().toU64());

    a.setFlags(flags);
    testing.expectEqual(@as(u64, 0x000fffff_ffff2000), a.getAddr().value);
    testing.expectEqual(@as(u64, 1), a.getFlags().toU64());

    addr.value = 0x000fffff_ffff3000;
    testing.expectEqual(@as(u64, 0x000fffff_ffff2000), a.getAddr().value);

    a.setAddr(addr);
    testing.expectEqual(@as(u64, 0x000fffff_ffff3000), a.getAddr().value);
    testing.expectEqual(@as(u64, 1), a.getFlags().toU64());
}

/// Possible flags for a page table entry.
pub const PageTableFlags = packed struct {
    /// Specifies whether the mapped frame or page table is loaded in memory.
    present: bool,
    /// Controls whether writes to the mapped frames are allowed.
    ///
    /// If this bit is unset in a level 1 page table entry, the mapped frame is read-only.
    /// If this bit is unset in a higher level page table entry the complete range of mapped
    /// pages is read-only.
    writable: bool,
    /// Controls whether accesses from userspace (i.e. ring 3) are permitted.
    user_accessible: bool,
    /// If this bit is set, a “write-through” policy is used for the cache, else a “write-back”
    /// policy is used.
    write_through: bool,
    /// Disables caching for the pointed entry is cacheable.
    no_cache: bool,
    /// Set by the CPU when the mapped frame or page table is accessed.
    accessed: bool,
    /// Set by the CPU on a write to the mapped frame.
    dirty: bool,
    /// Specifies that the entry maps a huge frame instead of a page table. Only allowed in
    /// P2 or P3 tables.
    huge_page: bool,
    /// Indicates that the mapping is present in all address spaces, so it isn't flushed from
    /// the TLB on an address space switch
    global: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    bit_9: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    bit_10: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    bit_11: bool,

    // I can't wait for better bitfields in Zig... this is a mess
    // These bits are used to store the physical frame
    _padding_1: u16,
    _padding_2: u8,
    _padding_31: bool,
    _padding_32: bool,
    _padding_33: bool,
    _padding_34: bool,
    _padding_35: bool,
    _padding_36: bool,
    _padding_37: bool,
    _padding_38: bool,
    _padding_41: bool,
    _padding_42: bool,
    _padding_43: bool,
    _padding_44: bool,
    _padding_45: bool,
    _padding_46: bool,
    _padding_47: bool,
    _padding_48: bool,

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    bit_52: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    bit_53: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    bit_54: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    bit_55: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    bit_56: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    bit_57: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    bit_58: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    bit_59: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    bit_60: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    bit_61: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    bit_62: bool,
    /// Forbid code execution from the mapped frames.
    ///
    /// Can be only used when the no-execute page protection feature is enabled in the EFER
    /// register.
    no_execute: bool,

    pub fn format(value: PageTableFlags, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll("PageTableFlags(");

        var something = false;

        if (value.present) {
            try writer.writeAll(" PRESENT ");
            something = true;
        } else {
            try writer.writeAll(" NOT_PRESENT ");
            something = true;
        }

        if (value.writable) {
            try writer.writeAll("- WRITEABLE ");
            something = true;
        }

        if (value.user_accessible) {
            try writer.writeAll("- USER_ACCESSIBLE ");
            something = true;
        }

        if (value.write_through) {
            try writer.writeAll("- WRITE_THROUGH ");
            something = true;
        }

        if (value.no_cache) {
            try writer.writeAll("- NO_CACHE ");
            something = true;
        }

        if (value.accessed) {
            try writer.writeAll("- ACCESSED ");
            something = true;
        }

        if (value.dirty) {
            try writer.writeAll("- DIRTY ");
            something = true;
        }

        if (value.huge_page) {
            try writer.writeAll("- HUGE_PAGE ");
            something = true;
        }

        if (value.global) {
            try writer.writeAll("- GLOBAL ");
            something = true;
        }

        if (value.global) {
            try writer.writeAll("- GLOBAL ");
            something = true;
        }

        if (value.no_execute) {
            try writer.writeAll("- NO_EXECUTE ");
            something = true;
        }

        if (!something) {
            try writer.writeAll(" NONE ");
        }

        try writer.writeAll(")");
    }

    // Create a blank/empty `PageTableFlags`
    pub inline fn init() PageTableFlags {
        return fromU64(0);
    }

    pub inline fn fromU64(value: u64) PageTableFlags {
        return @bitCast(PageTableFlags, value & NO_PADDING);
    }

    pub inline fn toU64(self: PageTableFlags) u64 {
        return @bitCast(u64, self) & NO_PADDING;
    }

    const NO_PADDING: u64 = @bitCast(u64, PageTableFlags{
        .present = true,
        .writable = true,
        .user_accessible = true,
        .write_through = true,
        .no_cache = true,
        .accessed = true,
        .dirty = true,
        .huge_page = true,
        .global = true,
        .bit_9 = true,
        .bit_10 = true,
        .bit_11 = true,
        ._padding_1 = 0,
        ._padding_2 = 0,
        ._padding_31 = false,
        ._padding_32 = false,
        ._padding_33 = false,
        ._padding_34 = false,
        ._padding_35 = false,
        ._padding_36 = false,
        ._padding_37 = false,
        ._padding_38 = false,
        ._padding_41 = false,
        ._padding_42 = false,
        ._padding_43 = false,
        ._padding_44 = false,
        ._padding_45 = false,
        ._padding_46 = false,
        ._padding_47 = false,
        ._padding_48 = false,
        .bit_52 = true,
        .bit_53 = true,
        .bit_54 = true,
        .bit_55 = true,
        .bit_56 = true,
        .bit_57 = true,
        .bit_58 = true,
        .bit_59 = true,
        .bit_60 = true,
        .bit_61 = true,
        .bit_62 = true,
        .no_execute = true,
    });

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "PageTableFlags" {
    std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(PageTableFlags));
    std.testing.expectEqual(@sizeOf(u64), @sizeOf(PageTableFlags));
}

/// The number of entries in a page table.
pub const ENTRY_COUNT: usize = 512;

/// Represents a page table.
/// Always page-sized.
/// **IMPORTANT** Must be align(4096)
pub const PageTable = extern struct {
    entries: [ENTRY_COUNT]PageTableEntry,

    /// Creates an empty page table.
    pub inline fn init() PageTable {
        return PageTable{ .entries = [_]PageTableEntry{PageTableEntry.init()} ** ENTRY_COUNT };
    }

    /// Clears all entries.
    pub inline fn zero(self: *PageTable) void {
        for (self.entries) |*entry| {
            entry.setUnused();
        }
    }

    pub inline fn getAtIndex(self: *PageTable, index: PageTableIndex) *PageTableEntry {
        return &self.entries[index.value];
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "" {
    var a = PageTable.init();
    a.zero();
}

/// A 12-bit offset into a 4KiB Page.
pub const PageOffset = packed struct {
    value: u16,

    /// Creates a new offset from the given `u16`. Panics if the passed value is >=4096.
    pub inline fn init(offset: u16) PageOffset {
        std.debug.assert(offset < (1 << 12));
        return PageOffset{ .value = offset };
    }

    /// Creates a new offset from the given `u16`. Throws away bits if the value is >=4096.
    pub inline fn initTruncate(offset: u16) PageOffset {
        return PageOffset{ .value = offset % (1 << 12) };
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

/// A 9-bit index into a page table.
pub const PageTableIndex = packed struct {
    value: u16,

    /// Creates a new index from the given `u16`. Panics if the given value is >=ENTRY_COUNT.
    pub inline fn init(index: u16) PageTableIndex {
        std.debug.assert(@as(usize, index) < ENTRY_COUNT);
        return PageTableIndex{ .value = index };
    }

    /// Creates a new index from the given `u16`. Throws away bits if the value is >=ENTRY_COUNT.
    pub inline fn initTruncate(index: u16) PageTableIndex {
        return PageTableIndex{ .value = index % @as(u16, ENTRY_COUNT) };
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "" {
    std.testing.refAllDecls(@This());
}
