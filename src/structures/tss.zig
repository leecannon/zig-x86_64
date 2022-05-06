const x86_64 = @import("../index.zig");
const bitjuggle = @import("bitjuggle");
const std = @import("std");

/// In 64-bit mode the TSS holds information that is not directly related to the task-switch mechanism,
/// but is used for finding kernel level stack if interrupts arrive while in kernel mode.
pub const TaskStateSegment = packed struct {
    reserved_1: u32 = 0,
    /// The full 64-bit canonical forms of the stack pointers (RSP) for privilege levels 0-2.
    privilege_stack_table: [3]x86_64.VirtAddr = [_]x86_64.VirtAddr{x86_64.VirtAddr.zero()} ** 3,
    reserved_2: u64 = 0,
    /// The full 64-bit canonical forms of the interrupt stack table (IST) pointers.
    interrupt_stack_table: [7]x86_64.VirtAddr = [_]x86_64.VirtAddr{x86_64.VirtAddr.zero()} ** 7,
    reserved_3: u64 = 0,
    reserved_4: u16 = 0,
    /// The 16-bit offset to the I/O permission bit map from the 64-bit TSS base.
    iomap_base: u16 = 0,

    /// Creates a new zeroed TSS
    /// WARNING: Deprecated
    pub fn init() TaskStateSegment {
        return .{};
    }

    test {
        std.testing.refAllDecls(@This());
        try std.testing.expectEqual(@bitSizeOf(u32) * 26, @bitSizeOf(TaskStateSegment));
        try std.testing.expectEqual(@sizeOf(u32) * 26, @sizeOf(TaskStateSegment));
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
