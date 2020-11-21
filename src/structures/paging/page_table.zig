usingnamespace @import("../../common.zig");

const PageSize = structures.paging.PageSize;

/// The error returned by the `PageTableEntry::frame` method.
pub const FrameError = error{
    /// The entry does not have the `PRESENT` flag set, so it isn't currently mapped to a frame.
    FrameNotPresent,
    /// The entry does have the `HUGE_PAGE` flag set. The `frame` method has a standard 4KiB frame
    /// as return type, so a huge frame can't be returned.
    HugeFrame,
};

/// A 64-bit page table entry.
pub const PageTableEntry = packed struct {
    entry: u64,

    /// Creates an unused page table entry.
    pub fn init() PageTableEntry {
        return PageTableEntry{ .entry = 0 };
    }

    /// Returns whether this entry is zero.
    pub fn is_unused(self: PageTableEntry) bool {
        return self.entry == 0;
    }

    /// Sets this entry to zero.
    pub fn set_unused(self: *PageTableEntry) void {
        self.entry = 0;
    }

    /// Returns the flags of this entry.
    pub fn get_flags(self: PageTableEntry) PageTableFlags {
        // Clear out the addr part of the entry
        var entry = self.entry;
        set_bits(&entry, 12, 40, 0);
        return PageTableFlags.from_u64(entry);
    }

    /// Returns the physical address mapped by this entry, might be zero.
    pub fn get_addr(self: PageTableEntry) PhysAddr {
        return PhysAddr.init(self.entry & 0x000fffff_fffff000);
    }

    /// Returns the physical frame mapped by this entry.
    ///
    /// Returns the following errors:
    ///
    /// - `FrameError::FrameNotPresent` if the entry doesn't have the `PRESENT` flag set.
    /// - `FrameError::HugeFrame` if the entry has the `HUGE_PAGE` flag set (for huge pages the
    ///    `addr` function must be used)
    pub fn get_frame(self: PageTableEntry) FrameError!structures.paging.PhysFrame4KiB {
        const flags = self.get_flags();

        if (!flags.PRESENT) {
            return FrameError.FrameNotPresent;
        }

        if (flags.HUGE_PAGE) {
            return FrameError.HugeFrame;
        }

        return structures.paging.PhysFrame4KiB.containing_address(self.get_addr());
    }

    /// Map the entry to the specified physical address
    pub fn set_addr(self: *PageTableEntry, addr: PhysAddr) void {
        std.debug.assert(addr.is_aligned(PageSize.Size4KiB.Size()));
        self.entry = addr.value | self.get_flags().to_u64();
    }

    /// Map the entry to the specified physical frame with the specified flags.
    pub fn set_frame(self: *PageTableEntry, frame: structures.paging.PhysFrame4KiB, flags: PageTableFlags) void {
        std.debug.assert(!self.get_flags().HUGE_PAGE);
        self.set_addr(frame.start_address, flags);
    }

    /// Sets the flags of this entry.
    pub fn set_flags(self: *PageTableEntry, flags: PageTableFlags) void {
        self.entry = self.get_addr().value | flags.to_u64();
    }

    pub fn format(value: PageTableEntry, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll("PageTableEntry(Addr = ");

        try std.fmt.formatType(
            value.get_addr(),
            "x",
            .{},
            writer,
            1,
        );

        try writer.writeAll(", Flags = ");

        try std.fmt.formatType(
            value.get_flags(),
            "b",
            .{},
            writer,
            1,
        );

        try writer.writeAll(")");
    }
};

test "PageTableEntry" {
    var a = PageTableEntry.init();

    var addr = PhysAddr.init(0x000fffff_ffff2000);
    var flags = PageTableFlags.init();

    a.set_addr(addr);
    a.set_flags(flags);

    testing.expectEqual(@as(u64, 0x000fffff_ffff2000), a.get_addr().value);
    testing.expectEqual(@as(u64, 0), a.get_flags().to_u64());

    flags.PRESENT = true;
    testing.expectEqual(@as(u64, 0), a.get_flags().to_u64());

    a.set_flags(flags);
    testing.expectEqual(@as(u64, 0x000fffff_ffff2000), a.get_addr().value);
    testing.expectEqual(@as(u64, 1), a.get_flags().to_u64());

    addr.value = 0x000fffff_ffff3000;
    testing.expectEqual(@as(u64, 0x000fffff_ffff2000), a.get_addr().value);

    a.set_addr(addr);
    testing.expectEqual(@as(u64, 0x000fffff_ffff3000), a.get_addr().value);
    testing.expectEqual(@as(u64, 1), a.get_flags().to_u64());
}

/// Possible flags for a page table entry.
pub const PageTableFlags = packed struct {
    /// Specifies whether the mapped frame or page table is loaded in memory.
    PRESENT: bool,
    /// Controls whether writes to the mapped frames are allowed.
    ///
    /// If this bit is unset in a level 1 page table entry, the mapped frame is read-only.
    /// If this bit is unset in a higher level page table entry the complete range of mapped
    /// pages is read-only.
    WRITABLE: bool,
    /// Controls whether accesses from userspace (i.e. ring 3) are permitted.
    USER_ACCESSIBLE: bool,
    /// If this bit is set, a “write-through” policy is used for the cache, else a “write-back”
    /// policy is used.
    WRITE_THROUGH: bool,
    /// Disables caching for the pointed entry is cacheable.
    NO_CACHE: bool,
    /// Set by the CPU when the mapped frame or page table is accessed.
    ACCESSED: bool,
    /// Set by the CPU on a write to the mapped frame.
    DIRTY: bool,
    /// Specifies that the entry maps a huge frame instead of a page table. Only allowed in
    /// P2 or P3 tables.
    HUGE_PAGE: bool,
    /// Indicates that the mapping is present in all address spaces, so it isn't flushed from
    /// the TLB on an address space switch
    GLOBAL: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    BIT_9: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    BIT_10: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    BIT_11: bool,

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
    BIT_52: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    BIT_53: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    BIT_54: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    BIT_55: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    BIT_56: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    BIT_57: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    BIT_58: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    BIT_59: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    BIT_60: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    BIT_61: bool,
    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    BIT_62: bool,
    /// Forbid code execution from the mapped frames.
    ///
    /// Can be only used when the no-execute page protection feature is enabled in the EFER
    /// register.
    NO_EXECUTE: bool,

    // Create a blank/empty `PageTableFlags`
    pub fn init() PageTableFlags {
        return from_u64(0);
    }

    pub fn from_u64(value: u64) PageTableFlags {
        return @bitCast(PageTableFlags, value & NO_PADDING);
    }

    pub fn to_u64(self: PageTableFlags) u64 {
        return @bitCast(u64, self) & NO_PADDING;
    }

    const NO_PADDING: u64 = @bitCast(u64, PageTableFlags{
        .PRESENT = true,
        .WRITABLE = true,
        .USER_ACCESSIBLE = true,
        .WRITE_THROUGH = true,
        .NO_CACHE = true,
        .ACCESSED = true,
        .DIRTY = true,
        .HUGE_PAGE = true,
        .GLOBAL = true,
        .BIT_9 = true,
        .BIT_10 = true,
        .BIT_11 = true,
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
        .BIT_52 = true,
        .BIT_53 = true,
        .BIT_54 = true,
        .BIT_55 = true,
        .BIT_56 = true,
        .BIT_57 = true,
        .BIT_58 = true,
        .BIT_59 = true,
        .BIT_60 = true,
        .BIT_61 = true,
        .BIT_62 = true,
        .NO_EXECUTE = true,
    });
};

test "PageTableFlags" {
    //std.debug.print("\nbit size:{}\nsize:{}\n", .{@bitSizeOf(PageTableFlags), @sizeOf(PageTableFlags)});
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
    pub fn init() PageTable {
        return PageTable{ .entries = [_]PageTableEntry{PageTableEntry.init()} ** ENTRY_COUNT };
    }

    /// Clears all entries.
    pub fn zero(self: *PageTable) void {
        for (self.entries) |*entry| {
            entry.set_unused();
        }
    }

    pub fn get_at_index(self: *PageTable, index: PageTableIndex) *PageTableEntry {
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
    pub fn init(offset: u16) PageOffset {
        std.debug.assert(offset < (1 << 12));
        return PageOffset{ .value = offset };
    }

    /// Creates a new offset from the given `u16`. Throws away bits if the value is >=4096.
    pub fn init_truncate(offset: u16) PageOffset {
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
    pub fn init(index: u16) PageTableIndex {
        std.debug.assert(@as(usize, index) < ENTRY_COUNT);
        return PageTableIndex{ .value = index };
    }

    /// Creates a new index from the given `u16`. Throws away bits if the value is >=ENTRY_COUNT.
    pub fn init_truncate(index: u16) PageTableIndex {
        return PageTableIndex{ .value = index % @as(u16, ENTRY_COUNT) };
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "" {
    std.testing.refAllDecls(@This());
}
