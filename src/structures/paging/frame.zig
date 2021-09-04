const x86_64 = @import("../../index.zig");
const bitjuggle = @import("bitjuggle");
const std = @import("std");

/// A physical memory frame. Page size 4 KiB
pub const PhysFrame = extern struct {
    const size: x86_64.structures.paging.PageSize = .Size4KiB;

    start_address: x86_64.PhysAddr,

    /// Returns the frame that starts at the given physical address.
    ///
    /// Returns an error if the address is not correctly aligned (i.e. is not a valid frame start)
    pub fn fromStartAddress(address: x86_64.PhysAddr) PhysFrameError!PhysFrame {
        if (!address.isAligned(size.bytes())) {
            return PhysFrameError.AddressNotAligned;
        }
        return containingAddress(address);
    }

    /// Returns the frame that starts at the given physical address.
    /// Without validaing the addresses alignment
    pub fn fromStartAddressUnchecked(address: x86_64.PhysAddr) PhysFrame {
        return .{ .start_address = address };
    }

    /// Returns the frame that contains the given physical address.
    pub fn containingAddress(address: x86_64.PhysAddr) PhysFrame {
        return .{
            .start_address = address.alignDown(size.bytes()),
        };
    }

    /// Returns the size of the frame (4KB, 2MB or 1GB).
    pub fn sizeOf(self: PhysFrame) u64 {
        _ = self;
        return size.bytes();
    }

    pub fn format(value: PhysFrame, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("PhysFrame[" ++ size.sizeString() ++ "](0x{x})", .{value.start_address.value});
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A physical memory frame. Page size 2 MiB
pub const PhysFrame2MiB = extern struct {
    const size: x86_64.structures.paging.PageSize = .Size2MiB;

    start_address: x86_64.PhysAddr,

    /// Returns the frame that starts at the given physical address.
    ///
    /// Returns an error if the address is not correctly aligned (i.e. is not a valid frame start)
    pub fn fromStartAddress(address: x86_64.PhysAddr) PhysFrameError!PhysFrame2MiB {
        if (!address.isAligned(size.bytes())) {
            return PhysFrameError.AddressNotAligned;
        }
        return containingAddress(address);
    }

    /// Returns the frame that starts at the given physical address.
    /// Without validaing the addresses alignment
    pub fn fromStartAddressUnchecked(address: x86_64.PhysAddr) PhysFrame2MiB {
        return .{ .start_address = address };
    }

    /// Returns the frame that contains the given physical address.
    pub fn containingAddress(address: x86_64.PhysAddr) PhysFrame2MiB {
        return .{
            .start_address = address.alignDown(size.bytes()),
        };
    }

    /// Returns the size of the frame (4KB, 2MB or 1GB).
    pub fn sizeOf(self: PhysFrame2MiB) u64 {
        _ = self;
        return size.bytes();
    }

    pub fn format(value: PhysFrame2MiB, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("PhysFrame[" ++ size.sizeString() ++ "](0x{x})", .{value.start_address.value});
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A physical memory frame. Page size 1 GiB
pub const PhysFrame1GiB = extern struct {
    const size: x86_64.structures.paging.PageSize = .Size1GiB;

    start_address: x86_64.PhysAddr,

    /// Returns the frame that starts at the given physical address.
    ///
    /// Returns an error if the address is not correctly aligned (i.e. is not a valid frame start)
    pub fn fromStartAddress(address: x86_64.PhysAddr) PhysFrameError!PhysFrame1GiB {
        if (!address.isAligned(size.bytes())) {
            return PhysFrameError.AddressNotAligned;
        }
        return containingAddress(address);
    }

    /// Returns the frame that starts at the given physical address.
    /// Without validaing the addresses alignment
    pub fn fromStartAddressUnchecked(address: x86_64.PhysAddr) PhysFrame1GiB {
        return .{ .start_address = address };
    }

    /// Returns the frame that contains the given physical address.
    pub fn containingAddress(address: x86_64.PhysAddr) PhysFrame1GiB {
        return .{
            .start_address = address.alignDown(size.bytes()),
        };
    }

    /// Returns the size of the frame (4KB, 2MB or 1GB).
    pub fn sizeOf(self: PhysFrame1GiB) u64 {
        _ = self;
        return size.bytes();
    }

    pub fn format(value: PhysFrame1GiB, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("PhysFrame[" ++ size.sizeString() ++ "](0x{x})", .{value.start_address.value});
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const PhysFrameError = error{AddressNotAligned};

/// Generates iterators for ranges of physical memory frame. Page size 4 KiB
pub const PhysFrameIterator = struct {
    /// Returns a range of frames, exclusive `end`.
    pub fn range(start: PhysFrame, end: PhysFrame) PhysFrameRange {
        return .{ .start = start, .end = end };
    }

    /// Returns a range of frames, inclusive `end`.
    pub fn rangeInclusive(start: PhysFrame, end: PhysFrame) PhysFrameRangeInclusive {
        return .{ .start = start, .end = end };
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Generates iterators for ranges of physical memory frame. Page size 2 MiB
pub const PhysFrameIterator2MiB = struct {
    /// Returns a range of frames, exclusive `end`.
    pub fn range(start: PhysFrame2MiB, end: PhysFrame2MiB) PhysFrameRange2MiB {
        return .{ .start = start, .end = end };
    }

    /// Returns a range of frames, inclusive `end`.
    pub fn rangeInclusive(start: PhysFrame2MiB, end: PhysFrame2MiB) PhysFrameRange2MiBInclusive {
        return .{ .start = start, .end = end };
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Generates iterators for ranges of physical memory frame. Page size 1 GiB
pub const PhysFrameIterator1GiB = struct {
    /// Returns a range of frames, exclusive `end`.
    pub fn range(start: PhysFrame1GiB, end: PhysFrame1GiB) PhysFrameRange1GiB {
        return .{ .start = start, .end = end };
    }

    /// Returns a range of frames, inclusive `end`.
    pub fn rangeInclusive(start: PhysFrame1GiB, end: PhysFrame1GiB) PhysFrameRange1GiBInclusive {
        return .{ .start = start, .end = end };
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A range of physical memory frames, exclusive the upper bound. Page size 4 KiB
pub const PhysFrameRange = struct {
    /// The start of the range, inclusive.
    start: ?PhysFrame,
    /// The end of the range, exclusive.
    end: PhysFrame,

    /// Returns whether the range contains no frames.
    pub fn isEmpty(self: PhysFrameRange) bool {
        if (self.start) |x| {
            return x.start_address.value >= self.end.start_address.value;
        }
        return true;
    }

    pub fn next(self: *PhysFrameRange) ?PhysFrame {
        if (self.start) |start| {
            if (start.start_address.value < self.end.start_address.value) {
                const frame = start;

                const opt_addr = x86_64.PhysAddr.init(start.start_address.value + PhysFrame.size.bytes()) catch null;

                if (opt_addr) |addr| {
                    self.start = PhysFrame.containingAddress(addr);
                } else {
                    self.start = null;
                }

                return frame;
            }
        }
        return null;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A range of physical memory frames, exclusive the upper bound. Page size 2 MiB
pub const PhysFrameRange2MiB = struct {
    /// The start of the range, inclusive.
    start: ?PhysFrame2MiB,
    /// The end of the range, exclusive.
    end: PhysFrame2MiB,

    /// Returns whether the range contains no frames.
    pub fn isEmpty(self: PhysFrameRange2MiB) bool {
        if (self.start) |x| {
            return x.start_address.value >= self.end.start_address.value;
        }
        return true;
    }

    pub fn next(self: *PhysFrameRange2MiB) ?PhysFrame2MiB {
        if (self.start) |start| {
            if (start.start_address.value < self.end.start_address.value) {
                const frame = start;

                const opt_addr = x86_64.PhysAddr.init(start.start_address.value + PhysFrame2MiB.size.bytes()) catch null;

                if (opt_addr) |addr| {
                    self.start = PhysFrame2MiB.containingAddress(addr);
                } else {
                    self.start = null;
                }

                return frame;
            }
        }
        return null;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A range of physical memory frames, exclusive the upper bound. Page size 1 GiB
pub const PhysFrameRange1GiB = struct {
    /// The start of the range, inclusive.
    start: ?PhysFrame1GiB,
    /// The end of the range, exclusive.
    end: PhysFrame1GiB,

    /// Returns whether the range contains no frames.
    pub fn isEmpty(self: PhysFrameRange1GiB) bool {
        if (self.start) |x| {
            return x.start_address.value >= self.end.start_address.value;
        }
        return true;
    }

    pub fn next(self: *PhysFrameRange1GiB) ?PhysFrame1GiB {
        if (self.start) |start| {
            if (start.start_address.value < self.end.start_address.value) {
                const frame = start;

                const opt_addr = x86_64.PhysAddr.init(start.start_address.value + PhysFrame1GiB.size.bytes()) catch null;

                if (opt_addr) |addr| {
                    self.start = PhysFrame1GiB.containingAddress(addr);
                } else {
                    self.start = null;
                }

                return frame;
            }
        }
        return null;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// An range of physical memory frames, inclusive the upper bound. Page size 4 KiB
pub const PhysFrameRangeInclusive = struct {
    /// The start of the range, inclusive.
    start: ?PhysFrame,
    /// The end of the range, inclusive.
    end: PhysFrame,

    /// Returns whether the range contains no frames.
    pub fn isEmpty(self: PhysFrameRangeInclusive) bool {
        if (self.start) |x| {
            return x.start_address.value > self.end.start_address.value;
        }
        return true;
    }

    pub fn next(self: *PhysFrameRangeInclusive) ?PhysFrame {
        if (self.start) |start| {
            if (start.start_address.value <= self.end.start_address.value) {
                const frame = start;

                const opt_addr = x86_64.PhysAddr.init(start.start_address.value + PhysFrame.size.bytes()) catch null;

                if (opt_addr) |addr| {
                    self.start = PhysFrame.containingAddress(addr);
                } else {
                    self.start = null;
                }

                return frame;
            }
        }
        return null;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// An range of physical memory frames, inclusive the upper bound. Page size 2 MiB
pub const PhysFrameRange2MiBInclusive = struct {
    /// The start of the range, inclusive.
    start: ?PhysFrame2MiB,
    /// The end of the range, inclusive.
    end: PhysFrame2MiB,

    /// Returns whether the range contains no frames.
    pub fn isEmpty(self: PhysFrameRange2MiBInclusive) bool {
        if (self.start) |x| {
            return x.start_address.value > self.end.start_address.value;
        }
        return true;
    }

    pub fn next(self: *PhysFrameRange2MiBInclusive) ?PhysFrame2MiB {
        if (self.start) |start| {
            if (start.start_address.value <= self.end.start_address.value) {
                const frame = start;

                const opt_addr = x86_64.PhysAddr.init(start.start_address.value + PhysFrame2MiB.size.bytes()) catch null;

                if (opt_addr) |addr| {
                    self.start = PhysFrame2MiB.containingAddress(addr);
                } else {
                    self.start = null;
                }

                return frame;
            }
        }
        return null;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// An range of physical memory frames, inclusive the upper bound. Page size 1 GiB
pub const PhysFrameRange1GiBInclusive = struct {
    /// The start of the range, inclusive.
    start: ?PhysFrame1GiB,
    /// The end of the range, inclusive.
    end: PhysFrame1GiB,

    /// Returns whether the range contains no frames.
    pub fn isEmpty(self: PhysFrameRange1GiBInclusive) bool {
        if (self.start) |x| {
            return x.start_address.value > self.end.start_address.value;
        }
        return true;
    }

    pub fn next(self: *PhysFrameRange1GiBInclusive) ?PhysFrame1GiB {
        if (self.start) |start| {
            if (start.start_address.value <= self.end.start_address.value) {
                const frame = start;

                const opt_addr = x86_64.PhysAddr.init(start.start_address.value + PhysFrame1GiB.size.bytes()) catch null;

                if (opt_addr) |addr| {
                    self.start = PhysFrame1GiB.containingAddress(addr);
                } else {
                    self.start = null;
                }

                return frame;
            }
        }
        return null;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

test "PhysFrameIterator" {
    var physAddrA = x86_64.PhysAddr.initPanic(0x000FFFFFFFFF0000);
    physAddrA = physAddrA.alignDown(x86_64.structures.paging.PageSize.Size4KiB.bytes());

    var physAddrB = x86_64.PhysAddr.initPanic(0x000FFFFFFFFFFFFF);
    physAddrB = physAddrB.alignDown(x86_64.structures.paging.PageSize.Size4KiB.bytes());

    const a = try PhysFrame.fromStartAddress(physAddrA);
    const b = try PhysFrame.fromStartAddress(physAddrB);

    var iterator = PhysFrameIterator.range(a, b);
    var inclusive_iterator = PhysFrameIterator.rangeInclusive(a, b);

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
