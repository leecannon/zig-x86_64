usingnamespace @import("../common.zig");

/// In 64-bit mode the TSS holds information that is not
/// directly related to the task-switch mechanism,
/// but is used for finding kernel level stack
/// if interrupts arrive while in kernel mode.
pub const TaskStateSegment = packed struct {
    reserved_1: u32,
    /// The full 64-bit canonical forms of the stack pointers (RSP) for privilege levels 0-2.
    privilege_stack_table: [3]VirtAddr,
    reserved_2: u64,
    /// The full 64-bit canonical forms of the interrupt stack table (IST) pointers.
    interrupt_stack_table: [7]VirtAddr,
    reserved_3: u64,
    reserved_4: u16,
    /// The 16-bit offset to the I/O permission bit map from the 64-bit TSS base.
    iomap_base: u16,

    /// Creates a new TSS with zeroed privilege and interrupt stack table and a zero
    /// `iomap_base`.
    pub inline fn init() TaskStateSegment {
        return TaskStateSegment{
            .reserved_1 = 0,
            .privilege_stack_table = [_]VirtAddr{VirtAddr.init(0)} ** 3,
            .reserved_2 = 0,
            .interrupt_stack_table = [_]VirtAddr{VirtAddr.init(0)} ** 7,
            .reserved_3 = 0,
            .reserved_4 = 0,
            .iomap_base = 0,
        };
    }
};

test "TaskStateSegment" {
    std.testing.expectEqual(@bitSizeOf(u32) * 26, @bitSizeOf(TaskStateSegment));
    std.testing.expectEqual(@sizeOf(u32) * 26, @sizeOf(TaskStateSegment));
}

test "" {
    std.meta.refAllDecls(@This());
}
