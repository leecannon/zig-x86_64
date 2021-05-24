usingnamespace @import("../../common.zig");

const paging = x86_64.structures.paging;

pub const FrameAllocator = struct {
    z_impl_allocateFrame: fn (frameAllocator: *FrameAllocator) ?paging.PhysFrame,
    z_impl_allocateFrame2MiB: fn (frameAllocator: *FrameAllocator) ?paging.PhysFrame2MiB,
    z_impl_allocateFrame1GiB: fn (frameAllocator: *FrameAllocator) ?paging.PhysFrame1GiB,
    z_impl_deallocateFrame: fn (frameAllocator: *FrameAllocator, frame: paging.PhysFrame) void,
    z_impl_deallocateFrame2MiB: fn (frameAllocator: *FrameAllocator, frame: paging.PhysFrame2MiB) void,
    z_impl_deallocateFrame1GiB: fn (frameAllocator: *FrameAllocator, frame: paging.PhysFrame1GiB) void,

    pub inline fn allocate4KiB(frameAllocator: *FrameAllocator) ?paging.PhysFrame {
        return frameAllocator.allocateFrame(.Size4KiB);
    }

    pub inline fn allocate2MiB(frameAllocator: *FrameAllocator) ?paging.PhysFrame2MiB {
        return frameAllocator.allocateFrame(.Size2MiB);
    }

    pub inline fn allocate1GiB(frameAllocator: *FrameAllocator) ?paging.PhysFrame1GiB {
        return frameAllocator.allocateFrame(.Size1GiB);
    }

    pub inline fn deallocate4KiB(frameAllocator: *FrameAllocator, frame: paging.PhysFrame) void {
        return frameAllocator.deallocateFrame(.Size4KiB, frame);
    }

    pub inline fn deallocate2MiB(frameAllocator: *FrameAllocator, frame: paging.PhysFrame2MiB) void {
        return frameAllocator.deallocateFrame(.Size2MiB, frame);
    }

    pub inline fn deallocate1GiB(frameAllocator: *FrameAllocator, frame: paging.PhysFrame1GiB) void {
        return frameAllocator.deallocateFrame(.Size1GiB, frame);
    }

    /// Allocate a frame of the appropriate size and return it if possible.
    pub inline fn allocateFrame(frameAllocator: *FrameAllocator, comptime size: paging.PageSize) ?paging.CreatePhysFrame(size) {
        return switch (size) {
            .Size4KiB => frameAllocator.z_impl_allocateFrame(frameAllocator),
            .Size2MiB => frameAllocator.z_impl_allocateFrame2MiB(frameAllocator),
            .Size1GiB => frameAllocator.z_impl_allocateFrame1GiB(frameAllocator),
        };
    }

    /// Deallocate the given unused frame.
    pub inline fn deallocateFrame(frameAllocator: *FrameAllocator, comptime size: paging.PageSize, frame: paging.CreatePhysFrame(size)) void {
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
