usingnamespace @import("../../common.zig");

const paging = structures.paging;

pub const FrameAllocator = struct {
    z_impl_allocateFrame: fn (frameAllocator: *FrameAllocator) ?paging.PhysFrame,
    z_impl_allocateFrame2MiB: fn (frameAllocator: *FrameAllocator) ?paging.PhysFrame2MiB,
    z_impl_allocateFrame1GiB: fn (frameAllocator: *FrameAllocator) ?paging.PhysFrame1GiB,
    z_impl_deallocateFrame: fn (frameAllocator: *FrameAllocator, frame: paging.PhysFrame) void,
    z_impl_deallocateFrame2MiB: fn (frameAllocator: *FrameAllocator, frame: paging.PhysFrame2MiB) void,
    z_impl_deallocateFrame1GiB: fn (frameAllocator: *FrameAllocator, frame: paging.PhysFrame1GiB) void,

    /// Allocate a frame of the appropriate size and return it if possible.
    pub fn allocateFrame(frameAllocator: *FrameAllocator, comptime size: paging.PageSize) callconv(.Inline) ?paging.CreatePhysFrame(size) {
        return switch (size) {
            .Size4KiB => frameAllocator.z_impl_allocateFrame(frameAllocator),
            .Size2MiB => frameAllocator.z_impl_allocateFrame(frameAllocator),
            .Size1GiB => frameAllocator.z_impl_allocateFrame(frameAllocator),
        };
    }

    /// Deallocate the given unused frame.
    pub fn deallocateFrame(frameAllocator: *FrameAllocator, comptime size: paging.PageSize, frame: paging.CreatePhysFrame(size)) callconv(.Inline) void {
        switch (size) {
            .Size4KiB => frameAllocator.z_impl_deallocateFrame(frameAllocator, frame),
            .Size2MiB => frameAllocator.z_impl_deallocateFrame2MiB(frameAllocator, frame),
            .Size1GiB => frameAllocator.z_impl_deallocateFrame1GiB(frameAllocator, frame),
        }
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
