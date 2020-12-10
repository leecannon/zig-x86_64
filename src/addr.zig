usingnamespace @import("common.zig");

pub const VirtAddrError = error{VirtAddrNotValid};

/// A canonical 64-bit virtual memory address.
///
/// On `x86_64`, only the 48 lower bits of a virtual address can be used. The top 16 bits need
/// to be copies of bit 47, i.e. the most significant bit. Addresses that fulfil this criterium
/// are called “canonical”. This type guarantees that it always represents a canonical address.
pub const VirtAddr = packed struct {
    value: u64,

    /// Creates a new canonical virtual address.
    ///
    /// This function performs sign extension of bit 47 to make the address canonical. Panics
    /// if the bits in the range 48 to 64 contain data (i.e. are not null and no sign extension).
    pub inline fn init(addr: u64) VirtAddr {
        return tryNew(addr) catch |_| {
            @panic("addr must not contain any data in bits 48 to 64");
        };
    }

    /// Tries to create a new canonical virtual address.
    ///
    /// This function tries to performs sign
    /// extension of bit 47 to make the address canonical. It succeeds if bits 48 to 64 are
    /// either a correct sign extension (i.e. copies of bit 47) or all null. Else, an error
    /// is returned.
    pub fn tryNew(addr: u64) VirtAddrError!VirtAddr {
        return switch (getBits(addr, 48, 16)) {
            0, 0xffff => VirtAddr{ .value = addr },
            1 => initTruncate(addr),
            else => return VirtAddrError.VirtAddrNotValid,
        };
    }

    /// Creates new virtual address, without any checks.
    ///
    /// You must make sure bits 48..64 are equal to bit 47.
    pub inline fn initUnchecked(addr: u64) VirtAddr {
        return .{ .value = addr };
    }

    /// Creates a virtual address that points to `0`
    pub inline fn zero() VirtAddr {
        return .{ .value = 0 };
    }

    /// Creates a new canonical virtual address, throwing out bits 48..64.
    ///
    /// This function performs sign extension of bit 47 to make the address canonical, so
    /// bits 48 to 64 are overwritten. If you want to check that these bits contain no data,
    /// use `new` or `tryNew`.
    pub inline fn initTruncate(addr: u64) VirtAddr {
        return VirtAddr{ .value = @intCast(u64, @intCast(i64, (addr << 16)) >> 16) };
    }

    /// Convenience method for checking if a virtual address is null.
    pub inline fn isNull(self: VirtAddr) bool {
        return self.value == 0;
    }

    /// Creates a virtual address from the given pointer
    pub inline fn fromPtr(ptr: anytype) VirtAddr {
        comptime {
            if (@typeInfo(@TypeOf(ptr)) != .Pointer) @compileError("not a pointer");
        }
        return VirtAddr.init(@ptrToInt(ptr));
    }

    /// Aligns the virtual address upwards to the given alignment.
    pub inline fn alignUp(self: VirtAddr, alignment: u64) VirtAddr {
        return VirtAddr.init(rawAlignUp(self.value, alignment));
    }

    /// Aligns the virtual address downwards to the given alignment.
    pub inline fn alignDown(self: VirtAddr, alignment: u64) VirtAddr {
        return VirtAddr.init(rawAlignDown(self.value, alignment));
    }

    /// Checks whether the virtual address has the given alignment.
    pub inline fn isAligned(self: VirtAddr, alignment: u64) bool {
        return rawAlignDown(self.value, alignment) == self.value;
    }

    /// Returns the 12-bit page offset of this virtual address.
    pub inline fn pageOffset(self: VirtAddr) structures.paging.PageOffset {
        return structures.paging.PageOffset.initTruncate(@intCast(u16, self.value));
    }

    /// Returns the 9-bit level 1 page table index.
    pub inline fn getP1Index(self: VirtAddr) structures.paging.PageTableIndex {
        return structures.paging.PageTableIndex.initTruncate(@intCast(u16, self.value >> 12));
    }

    /// Returns the 9-bit level 2 page table index.
    pub inline fn getP2Index(self: VirtAddr) structures.paging.PageTableIndex {
        return structures.paging.PageTableIndex.initTruncate(@intCast(u16, self.value >> 12 >> 9));
    }

    /// Returns the 9-bit level 3 page table index.
    pub inline fn getP3Index(self: VirtAddr) structures.paging.PageTableIndex {
        return structures.paging.PageTableIndex.initTruncate(@intCast(u16, self.value >> 12 >> 9 >> 9));
    }

    /// Returns the 9-bit level 4 page table index.
    pub inline fn getP4Index(self: VirtAddr) structures.paging.PageTableIndex {
        return structures.paging.PageTableIndex.initTruncate(@intCast(u16, self.value >> 12 >> 9 >> 9 >> 9));
    }

    pub fn format(value: VirtAddr, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll("VirtAddr(0x");

        try std.fmt.formatType(
            value.value,
            "x",
            .{},
            writer,
            1,
        );

        try writer.writeAll(")");
    }
};

pub const PhysAddrError = error{PhysAddrNotValid};

/// A 64-bit physical memory address.
///
/// On `x86_64`, only the 52 lower bits of a physical address can be used. The top 12 bits need
/// to be zero. This type guarantees that it always represents a valid physical address.
pub const PhysAddr = packed struct {
    const Zero = PhysAddr{ .value = 0 };

    value: u64,

    /// Creates a new physical address.
    ///
    /// Panics if a bit in the range 52 to 64 is set.
    pub inline fn init(addr: u64) PhysAddr {
        return tryNew(addr) catch |_| @panic("addr must not contain any data in bits 52 to 64");
    }

    /// Creates new physical address, without any checks.
    ///
    /// You must make sure bits 52..64 are zero.
    pub inline fn initUnchecked(addr: u64) PhysAddr {
        return .{ .value = addr };
    }

    /// Tries to create a new physical address.
    ///
    /// Fails if any bits in the range 52 to 64 are set.
    pub fn tryNew(addr: u64) PhysAddrError!PhysAddr {
        return switch (getBits(addr, 52, 12)) {
            0 => PhysAddr{ .value = addr },
            else => return PhysAddrError.PhysAddrNotValid,
        };
    }

    /// Creates a new physical address, throwing bits 52..64 away.
    pub inline fn initTruncate(addr: u64) PhysAddr {
        return PhysAddr{ .value = addr & @as(u64, 1) << 52 };
    }

    /// Creates a physical address that points to `0`
    pub inline fn zero() PhysAddr {
        return .{ .value = 0 };
    }

    /// Convenience method for checking if a physical address is null.
    pub inline fn isNull(self: PhysAddr) bool {
        return self.value == 0;
    }

    /// Aligns the physical address upwards to the given alignment.
    pub inline fn alignUp(self: PhysAddr, alignment: u64) PhysAddr {
        return PhysAddr.init(rawAlignUp(self.value, alignment));
    }

    /// Aligns the physical address downwards to the given alignment.
    pub inline fn alignDown(self: PhysAddr, alignment: u64) PhysAddr {
        return PhysAddr.init(rawAlignDown(self.value, alignment));
    }

    /// Checks whether the physical address has the given alignment.
    pub inline fn isAligned(self: PhysAddr, alignment: u64) bool {
        return rawAlignDown(self.value, alignment) == self.value;
    }

    pub fn format(value: PhysAddr, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll("PhysAddr(0x");

        try std.fmt.formatType(
            value.value,
            "x",
            .{},
            writer,
            1,
        );

        try writer.writeAll(")");
    }
};

/// Align address downwards.
///
/// Returns the greatest x with alignment `align` so that x <= addr. The alignment must be
///  a power of 2.
pub inline fn rawAlignDown(addr: u64, alignment: u64) u64 {
    std.debug.assert(std.math.isPowerOfTwo(alignment));
    return addr & ~(alignment - 1);
}

/// Align address upwards.
///
/// Returns the smallest x with alignment `align` so that x >= addr. The alignment must be
/// a power of 2.
pub inline fn rawAlignUp(addr: u64, alignment: u64) u64 {
    std.debug.assert(std.math.isPowerOfTwo(alignment));

    const align_mask = alignment - 1;

    if (addr & align_mask == 0) {
        // Already aligned
        return addr;
    }

    return (addr | align_mask) + 1;
}

test "" {
    std.testing.refAllDecls(@This());
}
