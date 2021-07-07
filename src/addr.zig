usingnamespace @import("common.zig");

const PageTableIndex = x86_64.structures.paging.PageTableIndex;
const PageOffset = x86_64.structures.paging.PageOffset;

/// A canonical 64-bit virtual memory address.
///
/// On `x86_64`, only the 48 lower bits of a virtual address can be used. The top 16 bits need
/// to be copies of bit 47, i.e. the most significant bit. Addresses that fulfil this criterium
/// are called “canonical”. This type guarantees that it always represents a canonical address.
pub const VirtAddr = packed struct {
    value: u64,

    /// Tries to create a new canonical virtual address.
    ///
    /// If required this function performs sign extension of bit 47 to make the address canonical.
    pub fn init(addr: u64) error{VirtAddrNotValid}!VirtAddr {
        return switch (bitjuggle.getBits(addr, 47, 17)) {
            0, 0x1ffff => VirtAddr{ .value = addr },
            1 => initTruncate(addr),
            else => return error.VirtAddrNotValid,
        };
    }

    /// Creates a new canonical virtual address.
    ///
    /// If required this function performs sign extension of bit 47 to make the address canonical.
    ///
    /// ## Panics
    /// This function panics if the bits in the range 48 to 64 contain data (i.e. are not null and no sign extension).
    pub fn initPanic(addr: u64) VirtAddr {
        return init(addr) catch @panic("address passed to VirtAddr.init_panic must not contain any data in bits 48 to 64");
    }

    /// Creates a new canonical virtual address, throwing out bits 48..64.
    ///
    /// If required this function performs sign extension of bit 47 to make the address canonical.
    pub fn initTruncate(addr: u64) VirtAddr {
        // By doing the right shift as a signed operation (on a i64), it will
        // sign extend the value, repeating the leftmost bit.

        // Split into individual ops:
        // const no_high_bits = addr << 16;
        // const as_i64 = @bitCast(i64, no_high_bits);
        // const sign_extend_high_bits = as_i64 >> 16;
        // const value = @bitCast(u64, sign_extend_high_bits);
        return VirtAddr{ .value = @bitCast(u64, @bitCast(i64, (addr << 16)) >> 16) };
    }

    /// Creates a new virtual address, without any checks.
    pub fn initUnchecked(addr: u64) VirtAddr {
        return .{ .value = addr };
    }

    /// Creates a virtual address that points to `0`.
    pub fn zero() VirtAddr {
        return .{ .value = 0 };
    }

    /// Convenience method for checking if a virtual address is null.
    pub fn isNull(self: VirtAddr) bool {
        return self.value == 0;
    }

    /// Creates a virtual address from the given pointer
    /// Panics if the given pointer is not a valid virtual address, this should never happen in reality
    pub fn fromPtr(ptr: anytype) VirtAddr {
        comptime if (@typeInfo(@TypeOf(ptr)) != .Pointer) @compileError("not a pointer");
        return initPanic(@ptrToInt(ptr));
    }

    /// Converts the address to a pointer.
    pub fn toPtr(self: VirtAddr, comptime T: type) T {
        return @intToPtr(T, self.value);
    }

    /// Aligns the virtual address upwards to the given alignment.
    /// The alignment must be a power of 2 and greater than 0.
    pub fn alignUp(self: VirtAddr, alignment: usize) VirtAddr {
        return .{ .value = std.mem.alignForward(self.value, alignment) };
    }

    /// Aligns the virtual address downwards to the given alignment.
    /// The alignment must be a power of 2 and greater than 0.
    pub fn alignDown(self: VirtAddr, alignment: usize) VirtAddr {
        return .{ .value = std.mem.alignBackward(self.value, alignment) };
    }

    /// Checks whether the virtual address has the given alignment.
    /// The alignment must be a power of 2 and greater than 0.
    pub fn isAligned(self: VirtAddr, alignment: usize) bool {
        return std.mem.isAligned(self.value, alignment);
    }

    /// Returns the 12-bit page offset of this virtual address.
    pub fn pageOffset(self: VirtAddr) PageOffset {
        return PageOffset.init(@truncate(u12, self.value));
    }

    /// Returns the 9-bit level 1 page table index.
    pub fn p1Index(self: VirtAddr) PageTableIndex {
        return PageTableIndex.init(@truncate(u9, self.value >> 12));
    }

    /// Returns the 9-bit level 2 page table index.
    pub fn p2Index(self: VirtAddr) PageTableIndex {
        return PageTableIndex.init(@truncate(u9, self.value >> 21));
    }

    /// Returns the 9-bit level 3 page table index.
    pub fn p3Index(self: VirtAddr) PageTableIndex {
        return PageTableIndex.init(@truncate(u9, self.value >> 30));
    }

    /// Returns the 9-bit level 4 page table index.
    pub fn p4Index(self: VirtAddr) PageTableIndex {
        return PageTableIndex.init(@truncate(u9, self.value >> 39));
    }

    pub fn format(value: VirtAddr, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("VirtAddr(0x{x})", .{value.value});
    }

    test {
        std.testing.refAllDecls(@This());
        try std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(VirtAddr));
        try std.testing.expectEqual(@sizeOf(u64), @sizeOf(VirtAddr));
    }
};

test "VirtAddr.initTruncate" {
    var virtAddr = VirtAddr.initTruncate(0);
    try std.testing.expectEqual(@as(u64, 0), virtAddr.value);

    virtAddr = VirtAddr.initTruncate(1 << 47);
    try std.testing.expectEqual(@as(u64, 0xfffff << 47), virtAddr.value);

    virtAddr = VirtAddr.initTruncate(123);
    try std.testing.expectEqual(@as(u64, 123), virtAddr.value);

    virtAddr = VirtAddr.initTruncate(123 << 47);
    try std.testing.expectEqual(@as(u64, 0xfffff << 47), virtAddr.value);
}

test "VirtAddr.init" {
    var virtAddr = try VirtAddr.init(0);
    try std.testing.expectEqual(@as(u64, 0), virtAddr.value);

    virtAddr = try VirtAddr.init(1 << 47);
    try std.testing.expectEqual(@as(u64, 0xfffff << 47), virtAddr.value);

    virtAddr = try VirtAddr.init(123);
    try std.testing.expectEqual(@as(u64, 123), virtAddr.value);

    try std.testing.expectError(error.VirtAddrNotValid, VirtAddr.init(123 << 47));
}

test "VirtAddr.fromPtr" {
    var something: usize = undefined;
    var somethingelse: usize = undefined;

    var virtAddr = VirtAddr.fromPtr(&something);
    try std.testing.expectEqual(@ptrToInt(&something), virtAddr.value);

    virtAddr = VirtAddr.fromPtr(&somethingelse);
    try std.testing.expectEqual(@ptrToInt(&somethingelse), virtAddr.value);
}

test "VirtAddr.toPtr" {
    var something: usize = undefined;

    var virtAddr = VirtAddr.fromPtr(&something);
    const ptr = virtAddr.toPtr(*usize);
    ptr.* = 123;

    try std.testing.expectEqual(@as(usize, 123), something);
}

test "VirtAddr.pageOffset/Index" {
    var something: usize = undefined;
    var virtAddr = VirtAddr.fromPtr(&something);

    try std.testing.expectEqual(@intCast(u12, bitjuggle.getBits(virtAddr.value, 0, 12)), virtAddr.pageOffset().value);
    try std.testing.expectEqual(@intCast(u9, bitjuggle.getBits(virtAddr.value, 12, 9)), virtAddr.p1Index().value);
    try std.testing.expectEqual(@intCast(u9, bitjuggle.getBits(virtAddr.value, 21, 9)), virtAddr.p2Index().value);
    try std.testing.expectEqual(@intCast(u9, bitjuggle.getBits(virtAddr.value, 30, 9)), virtAddr.p3Index().value);
    try std.testing.expectEqual(@intCast(u9, bitjuggle.getBits(virtAddr.value, 39, 9)), virtAddr.p4Index().value);
}

/// A 64-bit physical memory address.
///
/// On `x86_64`, only the 52 lower bits of a physical address can be used. The top 12 bits need
/// to be zero. This type guarantees that it always represents a valid physical address.
pub const PhysAddr = packed struct {
    value: u64,

    /// Tries to create a new physical address.
    ///
    /// Fails if any bits in the range 52 to 64 are set.
    pub fn init(addr: u64) error{PhysAddrNotValid}!PhysAddr {
        return switch (bitjuggle.getBits(addr, 52, 12)) {
            0 => PhysAddr{ .value = addr },
            else => return error.PhysAddrNotValid,
        };
    }

    /// Creates a new physical address.
    ///
    /// ## Panics
    /// This function panics if a bit in the range 52 to 64 is set.
    pub fn initPanic(addr: u64) PhysAddr {
        return init(addr) catch @panic("physical addresses must not have any bits in the range 52 to 64 set");
    }

    const TRUNCATE_CONST: u64 = 1 << 52;

    /// Creates a new physical address, throwing bits 52..64 away.
    pub fn initTruncate(addr: u64) PhysAddr {
        return PhysAddr{ .value = addr % TRUNCATE_CONST };
    }

    /// Creates a new physical address, without any checks.
    pub fn initUnchecked(addr: u64) PhysAddr {
        return .{ .value = addr };
    }

    /// Creates a physical address that points to `0`.
    pub fn zero() PhysAddr {
        return .{ .value = 0 };
    }

    /// Convenience method for checking if a physical address is null.
    pub fn isNull(self: PhysAddr) bool {
        return self.value == 0;
    }

    /// Aligns the physical address upwards to the given alignment.
    /// The alignment must be a power of 2 and greater than 0.
    pub fn alignUp(self: PhysAddr, alignment: usize) PhysAddr {
        return .{ .value = std.mem.alignForward(self.value, alignment) };
    }

    /// Aligns the physical address downwards to the given alignment.
    /// The alignment must be a power of 2 and greater than 0.
    pub fn alignDown(self: PhysAddr, alignment: usize) PhysAddr {
        return .{ .value = std.mem.alignBackward(self.value, alignment) };
    }

    /// Checks whether the physical address has the given alignment.
    /// The alignment must be a power of 2 and greater than 0.
    pub fn isAligned(self: PhysAddr, alignment: usize) bool {
        return std.mem.isAligned(self.value, alignment);
    }

    pub fn format(value: PhysAddr, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("PhysAddr(0x{x})", .{value.value});
    }

    test {
        std.testing.refAllDecls(@This());
        try std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(PhysAddr));
        try std.testing.expectEqual(@sizeOf(u64), @sizeOf(PhysAddr));
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
