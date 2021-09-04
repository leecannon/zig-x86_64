const x86_64 = @import("../../index.zig");
const bitjuggle = @import("bitjuggle");
const std = @import("std");
const formatWithoutFields = @import("../../common.zig").formatWithoutFields;

const PageSize = x86_64.structures.paging.PageSize;

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
        return PageTableFlags.fromU64(self.entry);
    }

    /// Returns the physical address mapped by this entry, might be zero.
    pub fn getAddr(self: PageTableEntry) x86_64.PhysAddr {
        // Unchecked is used as the mask ensures validity
        return x86_64.PhysAddr.initUnchecked(self.entry & 0x000f_ffff_ffff_f000);
    }

    /// Returns the physical frame mapped by this entry.
    ///
    /// Returns the following errors:
    ///
    /// - `FrameError::FrameNotPresent` if the entry doesn't have the `present` flag set.
    /// - `FrameError::HugeFrame` if the entry has the `huge_page` flag set (for huge pages the
    ///    `addr` function must be used)
    pub fn getFrame(self: PageTableEntry) FrameError!x86_64.structures.paging.PhysFrame {
        const flags = self.getFlags();

        if (!flags.present) {
            return FrameError.FrameNotPresent;
        }

        if (flags.huge) {
            return FrameError.HugeFrame;
        }

        return x86_64.structures.paging.PhysFrame.containingAddress(self.getAddr());
    }

    /// Map the entry to the specified physical address
    pub fn setAddr(self: *PageTableEntry, addr: x86_64.PhysAddr) void {
        std.debug.assert(addr.isAligned(PageSize.Size4KiB.bytes()));
        self.entry = addr.value | self.getFlags().toU64();
    }

    /// Map the entry to the specified physical frame with the specified flags.
    pub fn setFrame(self: *PageTableEntry, frame: x86_64.structures.paging.PhysFrame, flags: PageTableFlags) void {
        std.debug.assert(!self.getFlags().huge);
        self.setAddr(frame.start_address);
        self.setFlags(flags);
    }

    /// Sets the flags of this entry.
    pub fn setFlags(self: *PageTableEntry, flags: PageTableFlags) void {
        self.entry = self.getAddr().value | flags.toU64();
    }

    pub fn format(value: PageTableEntry, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("PageTableEntry({}, Flags = 0b{b})", .{ value.getAddr(), value.getFlags().value });
    }

    test {
        std.testing.refAllDecls(@This());
        try std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(PageTableEntry));
        try std.testing.expectEqual(@sizeOf(u64), @sizeOf(PageTableEntry));
    }
};

pub const PageTableFlags = packed struct {
    /// Specifies whether the mapped frame or page table is loaded in memory.
    present: bool = false,

    /// Controls whether writes to the mapped frames are allowed.
    ///
    /// If this bit is unset in a level 1 page table entry, the mapped frame is read-only.
    /// If this bit is unset in a higher level page table entry the complete range of mapped
    /// pages is read-only.
    writeable: bool = false,

    /// Controls whether accesses from userspace (i.e. ring 3) are permitted.
    user_accessible: bool = false,

    /// If this bit is set, a “write-through” policy is used for the cache, else a “write-back”
    /// policy is used.
    write_through: bool = false,

    /// Disables caching for the pointed entry is cacheable.
    no_cache: bool = false,

    /// Set by the CPU when the mapped frame or page table is accessed.
    accessed: bool = false,

    /// Set by the CPU on a write to the mapped frame.
    dirty: bool = false,

    /// Specifies that the entry maps a huge frame instead of a page table. Only allowed in
    /// P2 or P3 tables.
    huge: bool = false,

    /// Indicates that the mapping is present in all address spaces, so it isn't flushed from
    /// the TLB on an address space switch.
    global: bool = false,

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    bit_9_11: u3 = 0,

    z_reserved12_15: u4 = 0,
    z_reserved16_47: u32 = 0,
    z_reserved48_51: u4 = 0,

    /// Available to the OS, can be used to store additional data, e.g. custom flags.
    bit_52_62: u11 = 0,

    /// Forbid code execution from the mapped frames.
    ///
    /// Can be only used when the no-execute page protection feature is enabled in the EFER
    /// register.
    no_execute: bool = false,

    pub fn sanitizeForParent(self: PageTableFlags) PageTableFlags {
        var parent_flags = PageTableFlags{};
        if (self.present) parent_flags.present = true;
        if (self.writeable) parent_flags.writeable = true;
        if (self.user_accessible) parent_flags.user_accessible = true;
        return parent_flags;
    }

    pub fn fromU64(value: u64) PageTableFlags {
        return @bitCast(PageTableFlags, value & ALL_NOT_RESERVED);
    }

    pub fn toU64(self: PageTableFlags) u64 {
        return @bitCast(u64, self) & ALL_NOT_RESERVED;
    }

    const ALL_RESERVED: u64 = blk: {
        var flags = std.mem.zeroes(PageTableFlags);
        flags.z_reserved12_15 = std.math.maxInt(u4);
        flags.z_reserved16_47 = std.math.maxInt(u32);
        flags.z_reserved48_51 = std.math.maxInt(u4);
        break :blk @bitCast(u64, flags);
    };

    const ALL_NOT_RESERVED: u64 = ~ALL_RESERVED;

    pub fn format(value: PageTableFlags, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        return formatWithoutFields(
            value,
            options,
            writer,
            &.{
                "z_reserved",
                "bit_",
            },
        );
    }

    test {
        try std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(PageTableFlags));
        try std.testing.expectEqual(@sizeOf(u64), @sizeOf(PageTableFlags));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Represents a page table.
/// Always page-sized.
/// **IMPORTANT** Must be align(4096)
pub const PageTable = extern struct {
    entries: [PAGE_TABLE_ENTRY_COUNT]PageTableEntry = [_]PageTableEntry{PageTableEntry.init()} ** PAGE_TABLE_ENTRY_COUNT,

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
        _ = options;
        _ = fmt;
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
        _ = options;
        _ = fmt;
        try writer.print("PageOffset({})", .{value.value});
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
