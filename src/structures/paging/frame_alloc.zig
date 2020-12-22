usingnamespace @import("../../common.zig");

const paging = structures.paging;

pub const FrameAllocator = struct {
    impl_allocateFrame: fn (frameAllocator: *FrameAllocator) ?paging.PhysFrame,
    impl_allocateFrame2MiB: fn (frameAllocator: *FrameAllocator) ?paging.PhysFrame2MiB,
    impl_allocateFrame1GiB: fn (frameAllocator: *FrameAllocator) ?paging.PhysFrame1GiB,
    impl_deallocateFrame: fn (frameAllocator: *FrameAllocator, frame: paging.PhysFrame) void,
    impl_deallocateFrame2MiB: fn (frameAllocator: *FrameAllocator, frame: paging.PhysFrame2MiB) void,
    impl_deallocateFrame1GiB: fn (frameAllocator: *FrameAllocator, frame: paging.PhysFrame1GiB) void,

    /// Allocate a frame of the appropriate size and return it if possible.
    pub inline fn allocateFrame(frameAllocator: *FrameAllocator, comptime size: paging.PageSize) ?paging.CreatePhysFrame(size) {
        return switch (size) {
            .Size4KiB => frameAllocator.impl_allocateFrame(frameAllocator),
            .Size2MiB => frameAllocator.impl_allocateFrame(frameAllocator),
            .Size1GiB => frameAllocator.impl_allocateFrame(frameAllocator),
        };
    }

    /// Deallocate the given unused frame.
    pub inline fn deallocateFrame(frameAllocator: *FrameAllocator, comptime size: paging.PageSize, frame: paging.CreatePhysFrame(size)) void {
        switch (size) {
            .Size4KiB => frameAllocator.impl_deallocateFrame(frameAllocator, frame),
            .Size2MiB => frameAllocator.impl_deallocateFrame2MiB(frameAllocator, frame),
            .Size1GiB => frameAllocator.impl_deallocateFrame1GiB(frameAllocator, frame),
        }
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "" {
    std.testing.refAllDecls(@This());
}
