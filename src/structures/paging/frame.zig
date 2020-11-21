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
        pub fn from_start_address(address: PhysAddr) PhysFrameError!Self {
            if (!address.is_aligned(size.Size())) {
                return PhysFrameError.AddressNotAligned;
            }

            return Self{ .start_address = address };
        }

        /// Returns the frame that starts at the given physical address.
        /// Without validaing the addresses alignment
        pub fn from_start_address_unchecked(address: PhysAddr) Self {
            return Self{ .start_address = address };
        }

        /// Returns the frame that contains the given physical address.
        pub fn containing_address(address: PhysAddr) Self {
            return Self{
                .start_address = address.align_down(size.Size()),
            };
        }

        /// Returns the size of the frame (4KB, 2MB or 1GB).
        pub fn size_of(self: Self) u64 {
            return size.Size();
        }

        pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.writeAll("PhysFrame[" ++ size.SizeString() ++ "](0x");

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
    const physFrameRangeType = switch (phys_frame_type) {
        PhysFrame => PhysFrameRange,
        PhysFrame2MiB => PhysFrameRange2MiB,
        PhysFrame1GiB => PhysFrameRange1GiB,
        else => @compileError("Non-PhysFrame type given"),
    };

    const physFrameRangeInclusiveType = switch (phys_frame_type) {
        PhysFrame => PhysFrameRangeInclusive,
        PhysFrame2MiB => PhysFrameRange2MiBInclusive,
        PhysFrame1GiB => PhysFrameRange1GiBInclusive,
        else => @compileError("Non-PhysFrame type given"),
    };

    return struct {
        /// Returns a range of frames, exclusive `end`.
        pub fn range(start: phys_frame_type, end: phys_frame_type) physFrameRangeType {
            return physFrameRangeType{ .start = start, .end = end };
        }

        /// Returns a range of frames, inclusive `end`.
        pub fn range_inclusive(start: phys_frame_type, end: phys_frame_type) physFrameRangeInclusiveType {
            return physFrameRangeInclusiveType{ .start = start, .end = end };
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
        pub fn is_empty(self: Self) bool {
            if (self.start) |x| {
                return x.start_address.value >= self.end.start_address.value;
            }
            return true;
        }

        pub fn next(self: *Self) ?phys_frame_type {
            if (self.start) |start| {
                if (start.start_address.value < self.end.start_address.value) {
                    const frame = start;

                    const opt_addr = PhysAddr.try_new(start.start_address.value + phys_frame_type.size.Size()) catch null;

                    if (opt_addr) |addr| {
                        self.start = phys_frame_type.containing_address(addr);
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
        pub fn is_empty(self: Self) bool {
            if (self.start) |x| {
                return x.start_address.value > self.end.start_address.value;
            }
            return true;
        }

        pub fn next(self: *Self) ?phys_frame_type {
            if (self.start) |start| {
                if (start.start_address.value <= self.end.start_address.value) {
                    const frame = start;

                    const opt_addr = PhysAddr.try_new(start.start_address.value + phys_frame_type.size.Size()) catch null;

                    if (opt_addr) |addr| {
                        self.start = phys_frame_type.containing_address(addr);
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
    physAddrA = physAddrA.align_down(structures.paging.PageSize.Size4KiB.Size());

    var physAddrB = PhysAddr.init(0x000FFFFFFFFFFFFF);
    physAddrB = physAddrB.align_down(structures.paging.PageSize.Size4KiB.Size());

    const a = try PhysFrame.from_start_address(physAddrA);
    const b = try PhysFrame.from_start_address(physAddrB);

    var iterator = PhysFrameIterator.range(a, b);
    var inclusive_iterator = PhysFrameIterator.range_inclusive(a, b);

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
