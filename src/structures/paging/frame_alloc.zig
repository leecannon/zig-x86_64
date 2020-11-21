usingnamespace @import("../../common.zig");

/// A frame allocator interface. Page size 4 KiB
pub const FrameAllocator = CreateFrameAllocator(structures.paging.PageSize.Size4KiB);

/// A frame allocator interface. Page size 2 MiB
pub const FrameAllocator2MiB = CreateFrameAllocator(structures.paging.PageSize.Size2MiB);

/// A frame allocator interface. Page size 1 GiB
pub const FrameAllocator1GiB = CreateFrameAllocator(structures.paging.PageSize.Size1GiB);

fn CreateFrameAllocator(comptime page_size: structures.paging.PageSize) type {
    const physFrameType = switch (page_size) {
        .Size4KiB => structures.paging.PhysFrame,
        .Size2MiB => structures.paging.PhysFrame2MiB,
        .Size1GiB => structures.paging.PhysFrame1GiB,
    };

    return struct {
        const Self = @This();

        /// Allocate a frame of the appropriate size and return it if possible.
        allocate_frame: fn (self: *Self) ?physFrameType,
        /// Deallocate the given unused frame.
        deallocate_frame: fn (self: *Self, frame: physFrameType) void,

        test "" {
            std.testing.refAllDecls(@This());
        }
    };
}

test "" {
    std.testing.refAllDecls(@This());
}
