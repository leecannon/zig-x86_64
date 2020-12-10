usingnamespace @import("../../common.zig");

/// A physical memory frame. Page size 4 KiB
pub const PhysFrame = CreatePhysFrame(structures.paging.PageSize.Size4KiB);

/// A physical memory frame. Page size 2 MiB
pub const PhysFrame2MiB = CreatePhysFrame(structures.paging.PageSize.Size2MiB);

/// A physical memory frame. Page size 1 GiB
pub const PhysFrame1GiB = CreatePhysFrame(structures.paging.PageSize.Size1GiB);

pub const PhysFrameError = error{AddressNotAligned};

fn CreatePhysFrame(comptime page_size: structures.paging.PageSize) type {
    return struct {
        const Self = @This();
        const size: structures.paging.PageSize = page_size;
        start_address: PhysAddr,

        /// Returns the frame that starts at the given physical address.
        ///
        /// Returns an error if the address is not correctly aligned (i.e. is not a valid frame start)
        pub fn fromStartAddress(address: PhysAddr) PhysFrameError!Self {
            if (!address.isAligned(size.bytes())) {
                return PhysFrameError.AddressNotAligned;
            }

            return Self{ .start_address = address };
        }

        /// Returns the frame that starts at the given physical address.
        /// Without validaing the addresses alignment
        pub inline fn fromStartAddressUnchecked(address: PhysAddr) Self {
            return Self{ .start_address = address };
        }

        /// Returns the frame that contains the given physical address.
        pub inline fn containingAddress(address: PhysAddr) Self {
            return Self{
                .start_address = address.alignDown(size.bytes()),
            };
        }

        /// Returns the size of the frame (4KB, 2MB or 1GB).
        pub inline fn sizeOf(self: Self) u64 {
            return size.bytes();
        }

        pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.writeAll("PhysFrame[" ++ size.sizeString() ++ "](0x");

            try std.fmt.formatType(
                value.start_address.value,
                "x",
                .{},
                writer,
                1,
            );

            try writer.writeAll(")");
        }

        test "" {
            std.testing.refAllDecls(@This());
        }
    };
}

/// Generates iterators for ranges of physical memory frame. Page size 4 KiB
pub const PhysFrameIterator = CreatePhysFrameIterator(PhysFrame);

/// Generates iterators for ranges of physical memory frame. Page size 2 MiB
pub const PhysFrameIterator2MiB = CreatePhysFrameIterator(PhysFrame2MiB);

/// Generates iterators for ranges of physical memory frame. Page size 1 GiB
pub const PhysFrameIterator1GiB = CreatePhysFrameIterator(PhysFrame1GiB);

fn CreatePhysFrameIterator(comptime phys_frame_type: type) type {
    const phy_frame_range_type = switch (phys_frame_type) {
        PhysFrame => PhysFrameRange,
        PhysFrame2MiB => PhysFrameRange2MiB,
        PhysFrame1GiB => PhysFrameRange1GiB,
        else => @compileError("Non-PhysFrame type given"),
    };

    const phys_frame_range_inclusive_type = switch (phys_frame_type) {
        PhysFrame => PhysFrameRangeInclusive,
        PhysFrame2MiB => PhysFrameRange2MiBInclusive,
        PhysFrame1GiB => PhysFrameRange1GiBInclusive,
        else => @compileError("Non-PhysFrame type given"),
    };

    return struct {
        /// Returns a range of frames, exclusive `end`.
        pub inline fn range(start: phys_frame_type, end: phys_frame_type) phy_frame_range_type {
            return phy_frame_range_type{ .start = start, .end = end };
        }

        /// Returns a range of frames, inclusive `end`.
        pub inline fn rangeInclusive(start: phys_frame_type, end: phys_frame_type) phys_frame_range_inclusive_type {
            return phys_frame_range_inclusive_type{ .start = start, .end = end };
        }

        test "" {
            std.testing.refAllDecls(@This());
        }
    };
}

/// An range of physical memory frames, exclusive the upper bound. Page size 4 KiB
pub const PhysFrameRange = CreatePhysFrameRange(PhysFrame);

/// An range of physical memory frames, exclusive the upper bound. Page size 2 MiB
pub const PhysFrameRange2MiB = CreatePhysFrameRange(PhysFrame2MiB);

/// An range of physical memory frames, exclusive the upper bound. Page size 1 GiB
pub const PhysFrameRange1GiB = CreatePhysFrameRange(PhysFrame1GiB);

fn CreatePhysFrameRange(comptime phys_frame_type: type) type {
    comptime {
        if (phys_frame_type != PhysFrame and phys_frame_type != PhysFrame2MiB and phys_frame_type != PhysFrame1GiB) {
            @compileError("Non-PhysFrame type given");
        }
    }

    return struct {
        const Self = @This();

        /// The start of the range, inclusive.
        start: ?phys_frame_type,
        /// The end of the range, exclusive.
        end: phys_frame_type,

        /// Returns whether the range contains no frames.
        pub inline fn isEmpty(self: Self) bool {
            if (self.start) |x| {
                return x.start_address.value >= self.end.start_address.value;
            }
            return true;
        }

        pub fn next(self: *Self) ?phys_frame_type {
            if (self.start) |start| {
                if (start.start_address.value < self.end.start_address.value) {
                    const frame = start;

                    const opt_addr = PhysAddr.tryNew(start.start_address.value + phys_frame_type.size.bytes()) catch null;

                    if (opt_addr) |addr| {
                        self.start = phys_frame_type.containingAddress(addr);
                    } else {
                        self.start = null;
                    }

                    return frame;
                }
            }
            return null;
        }

        test "" {
            std.testing.refAllDecls(@This());
        }
    };
}

/// An range of physical memory frames, inclusive the upper bound. Page size 4 KiB
pub const PhysFrameRangeInclusive = CreatePhysFrameRangeInclusive(PhysFrame);

/// An range of physical memory frames, inclusive the upper bound. Page size 2 MiB
pub const PhysFrameRange2MiBInclusive = CreatePhysFrameRangeInclusive(PhysFrame2MiB);

/// An range of physical memory frames, inclusive the upper bound. Page size 1 GiB
pub const PhysFrameRange1GiBInclusive = CreatePhysFrameRangeInclusive(PhysFrame1GiB);

fn CreatePhysFrameRangeInclusive(comptime phys_frame_type: type) type {
    comptime {
        if (phys_frame_type != PhysFrame and phys_frame_type != PhysFrame2MiB and phys_frame_type != PhysFrame1GiB) {
            @compileError("Non-PhysFrame type given");
        }
    }

    return struct {
        const Self = @This();

        /// The start of the range, inclusive.
        start: ?phys_frame_type,
        /// The end of the range, inclusive.
        end: phys_frame_type,

        /// Returns whether the range contains no frames.
        pub inline fn isEmpty(self: Self) bool {
            if (self.start) |x| {
                return x.start_address.value > self.end.start_address.value;
            }
            return true;
        }

        pub fn next(self: *Self) ?phys_frame_type {
            if (self.start) |start| {
                if (start.start_address.value <= self.end.start_address.value) {
                    const frame = start;

                    const opt_addr = PhysAddr.tryNew(start.start_address.value + phys_frame_type.size.bytes()) catch null;

                    if (opt_addr) |addr| {
                        self.start = phys_frame_type.containingAddress(addr);
                    } else {
                        self.start = null;
                    }

                    return frame;
                }
            }
            return null;
        }

        test "" {
            std.testing.refAllDecls(@This());
        }
    };
}

test "PhysFrameIterator" {
    var physAddrA = PhysAddr.init(0x000FFFFFFFFF0000);
    physAddrA = physAddrA.alignDown(structures.paging.PageSize.Size4KiB.bytes());

    var physAddrB = PhysAddr.init(0x000FFFFFFFFFFFFF);
    physAddrB = physAddrB.alignDown(structures.paging.PageSize.Size4KiB.bytes());

    const a = try PhysFrame.fromStartAddress(physAddrA);
    const b = try PhysFrame.fromStartAddress(physAddrB);

    var iterator = PhysFrameIterator.range(a, b);
    var inclusive_iterator = PhysFrameIterator.rangeInclusive(a, b);

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
