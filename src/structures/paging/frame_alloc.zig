usingnamespace @import("../../common.zig");

const paging = x86_64.structures.paging;

pub const FrameAllocator = struct {
    z_impl_allocateFrame: fn (frame_allocator: *FrameAllocator) ?paging.PhysFrame,
    z_impl_allocateFrame2MiB: fn (frame_allocator: *FrameAllocator) ?paging.PhysFrame2MiB,
    z_impl_allocateFrame1GiB: fn (frame_allocator: *FrameAllocator) ?paging.PhysFrame1GiB,
    z_impl_deallocateFrame: fn (frame_allocator: *FrameAllocator, frame: paging.PhysFrame) void,
    z_impl_deallocateFrame2MiB: fn (frame_allocator: *FrameAllocator, frame: paging.PhysFrame2MiB) void,
    z_impl_deallocateFrame1GiB: fn (frame_allocator: *FrameAllocator, frame: paging.PhysFrame1GiB) void,

    pub inline fn allocate4KiB(frame_allocator: *FrameAllocator) ?paging.PhysFrame {
        return frame_allocator.z_impl_allocateFrame(frame_allocator);
    }

    pub inline fn allocate2MiB(frame_allocator: *FrameAllocator) ?paging.PhysFrame2MiB {
        return frame_allocator.z_impl_allocateFrame2MiB(frame_allocator);
    }

    pub inline fn allocate1GiB(frame_allocator: *FrameAllocator) ?paging.PhysFrame1GiB {
        return frame_allocator.z_impl_allocateFrame1GiB(frame_allocator);
    }

    pub inline fn deallocate4KiB(frame_allocator: *FrameAllocator, frame: paging.PhysFrame) void {
        return frame_allocator.z_impl_deallocateFrame(frame_allocator, frame);
    }

    pub inline fn deallocate2MiB(frame_allocator: *FrameAllocator, frame: paging.PhysFrame2MiB) void {
        return frame_allocator.z_impl_deallocateFrame2MiB(frame_allocator, frame);
    }

    pub inline fn deallocate1GiB(frame_allocator: *FrameAllocator, frame: paging.PhysFrame1GiB) void {
        return frame_allocator.z_impl_deallocateFrame1GiB(frame_allocator, frame);
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
