usingnamespace @import("../../common.zig");

const PageSize = structures.paging.PageSize;

/// The number of entries in a page table.
pub const PAGE_TABLE_ENTRY_COUNT: usize = 512;

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
    pub fn init() PageTableEntry {
        return .{ .entry = 0 };
    }

    /// Returns whether this entry is zero.
    pub fn isUnused(self: PageTableEntry) bool {
        return self.entry == 0;
    }

    /// Sets this entry to zero.
    pub fn setUnused(self: *PageTableEntry) void {
        self.entry = 0;
    }

    /// Returns the flags of this entry.
    pub fn getFlags(self: PageTableEntry) PageTableFlags {
        return PageTableFlags.init(self.entry);
    }

    /// Returns the physical address mapped by this entry, might be zero.
    pub fn getAddr(self: PageTableEntry) PhysAddr {
        // Unchecked is used as the mask ensures validity
        return PhysAddr.initUnchecked(self.entry & 0x000f_ffff_ffff_f000);
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

        if (flags.value & PageTableFlags.PRESENT == 0) {
            return FrameError.FrameNotPresent;
        }

        if (flags.value & PageTableFlags.HUGE_PAGE != 0) {
            return FrameError.HugeFrame;
        }

        return structures.paging.PhysFrame.containingAddress(self.getAddr());
    }

    /// Map the entry to the specified physical address
    pub fn setAddr(self: *PageTableEntry, addr: PhysAddr) void {
        std.debug.assert(addr.isAligned(PageSize.Size4KiB.bytes()));
        self.entry = addr.value | self.getFlags().value;
    }

    // TODO: implement this over comptime PageSize
    // Map the entry to the specified physical frame with the specified flags.
    // pub fn setFrame(self: *PageTableEntry, frame: structures.paging.PhysFrame, flags: PageTableFlags) void {
    //     std.debug.assert(self.getFlags().value & PageTableFlags.HUGE_PAGE == 0);
    //     self.setAddr(frame.start_address);
    //     self.setFlags(flags);
    // }

    /// Sets the flags of this entry.
    pub fn setFlags(self: *PageTableEntry, flags: PageTableFlags) void {
        self.entry = self.getAddr().value | flags.value;
    }

    pub fn format(value: PageTableEntry, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("PageTableEntry({}, Flags = 0b{b})", .{ value.getAddr(), value.getFlags().value });
    }

    comptime {
        std.testing.refAllDecls(@This());
        std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(PageTableEntry));
        std.testing.expectEqual(@sizeOf(u64), @sizeOf(PageTableEntry));
    }
};

pub const PageTableFlags = struct {
    value: u64,

    pub fn init(value: u64) PageTableFlags {
        return .{ .value = value & ALL };
    }

    pub const ALL: u64 =
        PRESENT | WRITABLE | USER_ACCESSIBLE | WRITE_THROUGH | NO_CACHE | ACCESSED |
        DIRTY | HUGE_PAGE | GLOBAL | BIT_9 | BIT_10 | BIT_11 | BIT_52 | BIT_53 | BIT_54 |
        BIT_55 | BIT_56 | BIT_57 | BIT_58 | BIT_59 | BIT_60 | BIT_61 | BIT_62 | NO_EXECUTE;
    pub const NOT_ALL: u64 = ~ALL;

    /// Specifies whether the mapped frame or page table is loaded in memory.
    pub const PRESENT: u64 = 1;
    pub const NOT_PRESENT: u64 = ~PRESENT;

    /// Controls whether writes to the mapped frames are allowed.
    ///
    /// If this bit is unset in a level 1 page table entry, the mapped frame is read-only.
    /// If this bit is unset in a higher level page table entry the complete range of mapped
    /// pages is read-only.
    pub const WRITABLE: u64 = 1 << 1;
    pub const NOT_WRITABLE: u64 = ~WRITABLE;

    /// Controls whether accesses from userspace (i.e. ring 3) are permitted.
    pub const USER_ACCESSIBLE: u64 = 1 << 2;
    pub const NOT_USER_ACCESSIBLE: u64 = ~USER_ACCESSIBLE;

    /// If this bit is set, a “write-through” policy is used for the cache, else a “write-back”
    /// policy is used.
    pub const WRITE_THROUGH: u64 = 1 << 3;
    pub const NOT_WRITE_THROUGH: u64 = ~WRITE_THROUGH;

    /// Disables caching for the pointed entry is cacheable.
    pub const NO_CACHE: u64 = 1 << 4;
    pub const NOT_NO_CACHE: u64 = ~NO_CACHE;

    /// Set by the CPU when the mapped frame or page table is accessed.
    pub const ACCESSED: u64 = 1 << 5;
    pub const NOT_ACCESSED: u64 = ~ACCESSED;

    /// Set by the CPU on a write to the mapped frame.
    pub const DIRTY: u64 = 1 << 6;
    pub const NOT_DIRTY: u64 = ~DIRTY;

    /// Specifies that the entry maps a huge frame instead of a page table. Only allowed in
    /// P2 or P3 tables.
    pub const HUGE_PAGE: u64 = 1 << 7;
    pub const NOT_HUGE_PAGE: u64 = ~HUGE_PAGE;

    /// Indicates that the mapping is present in all address spaces, so it isn't flushed from
    /// the TLB on an address space switch.
    pub const GLOBAL: u64 = 1 << 8;
    pub const NOT_GLOBAL: u64 = ~GLOBAL;

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    pub const BIT_9: u64 = 1 << 9;
    pub const NOT_BIT_9: u64 = ~BIT_9;

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    pub const BIT_10: u64 = 1 << 10;
    pub const NOT_BIT_10: u64 = ~BIT_10;

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    pub const BIT_11: u64 = 1 << 11;
    pub const NOT_BIT_11: u64 = ~BIT_11;

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    pub const BIT_52: u64 = 1 << 52;
    pub const NOT_BIT_52: u64 = ~BIT_52;

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    pub const BIT_53: u64 = 1 << 53;
    pub const NOT_BIT_53: u64 = ~BIT_53;

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    pub const BIT_54: u64 = 1 << 54;
    pub const NOT_BIT_54: u64 = ~BIT_54;

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    pub const BIT_55: u64 = 1 << 55;
    pub const NOT_BIT_55: u64 = ~BIT_55;

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    pub const BIT_56: u64 = 1 << 56;
    pub const NOT_BIT_56: u64 = ~BIT_56;

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    pub const BIT_57: u64 = 1 << 57;
    pub const NOT_BIT_57: u64 = ~BIT_57;

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    pub const BIT_58: u64 = 1 << 58;
    pub const NOT_BIT_58: u64 = ~BIT_58;

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    pub const BIT_59: u64 = 1 << 59;
    pub const NOT_BIT_59: u64 = ~BIT_59;

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    pub const BIT_60: u64 = 1 << 60;
    pub const NOT_BIT_60: u64 = ~BIT_60;

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    pub const BIT_61: u64 = 1 << 61;
    pub const NOT_BIT_61: u64 = ~BIT_61;

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    pub const BIT_62: u64 = 1 << 62;
    pub const NOT_BIT_62: u64 = ~BIT_62;

    /// Forbid code execution from the mapped frames.
    ///
    /// Can be only used when the no-execute page protection feature is enabled in the EFER
    /// register.
    pub const NO_EXECUTE: u64 = 1 << 63;
    pub const NOT_NO_EXECUTE: u64 = ~NO_EXECUTE;

    pub fn format(value: PageTableFlags, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll("PageTableFlags(");

        var something = false;

        if (value.value & PRESENT != 0) {
            try writer.writeAll(" PRESENT ");
            something = true;
        } else {
            try writer.writeAll(" NOT_PRESENT ");
            something = true;
        }

        if (value.value & WRITABLE != 0) {
            try writer.writeAll("- WRITEABLE ");
            something = true;
        }

        if (value.value & USER_ACCESSIBLE != 0) {
            try writer.writeAll("- USER_ACCESSIBLE ");
            something = true;
        }

        if (value.value & WRITE_THROUGH != 0) {
            try writer.writeAll("- WRITE_THROUGH ");
            something = true;
        }

        if (value.value & NO_CACHE != 0) {
            try writer.writeAll("- NO_CACHE ");
            something = true;
        }

        if (value.value & ACCESSED != 0) {
            try writer.writeAll("- ACCESSED ");
            something = true;
        }

        if (value.value & DIRTY != 0) {
            try writer.writeAll("- DIRTY ");
            something = true;
        }

        if (value.value & HUGE_PAGE != 0) {
            try writer.writeAll("- HUGE_PAGE ");
            something = true;
        }

        if (value.value & GLOBAL != 0) {
            try writer.writeAll("- GLOBAL ");
            something = true;
        }

        if (value.value & NO_EXECUTE != 0) {
            try writer.writeAll("- NO_EXECUTE ");
            something = true;
        }

        if (!something) {
            try writer.writeAll(" NONE ");
        }

        try writer.writeAll(")");
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Represents a page table.
/// Always page-sized.
/// **IMPORTANT** Must be align(4096)
pub const PageTable = extern struct {
    entries: [PAGE_TABLE_ENTRY_COUNT]PageTableEntry,

    /// Creates an empty page table.
    pub fn init() PageTable {
        return .{
            .entries = [_]PageTableEntry{PageTableEntry.init()} ** PAGE_TABLE_ENTRY_COUNT,
        };
    }

    /// Clears all entries.
    pub fn zero(self: *PageTable) void {
        for (self.entries) |*entry| {
            entry.setUnused();
        }
    }

    pub fn getAtIndex(self: *PageTable, index: PageTableIndex) *PageTableEntry {
        return &self.entries[index.value];
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A 9-bit index into a page table.
pub const PageTableIndex = struct {
    value: u9,

    /// Creates a new index from the given `u16`.
    pub fn init(index: u9) PageTableIndex {
        return .{ .value = index };
    }

    pub fn format(value: PageTableIndex, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("PageTableIndex({})", .{value.value});
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A 12-bit offset into a 4KiB Page.
pub const PageOffset = struct {
    value: u12,

    /// Creates a new offset from the given `u12`.
    pub fn init(offset: u12) PageOffset {
        return .{ .value = offset };
    }

    pub fn format(value: PageOffset, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("PageOffset({})", .{value.value});
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
