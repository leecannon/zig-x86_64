/// Functions to read and write control registers.
pub const control = @import("control.zig");

/// Processor state stored in the RFLAGS register.
pub const RFlags = @import("rflags.zig").RFlags;

/// Functions to read and write model specific registers.
pub const model_specific = @import("model_specific.zig");

usingnamespace @import("../common.zig");

/// Gets the current instruction pointer. Note that this is only approximate as it requires a few
/// instructions to execute.
pub fn readInstructionPointer() VirtAddr {
    return VirtAddr.initUnchecked(asm ("lea (%%rip), %[ret]"
        : [ret] "=r" (-> u64)
    ));
}

comptime {
    std.testing.refAllDecls(@This());
}
