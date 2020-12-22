/// Functions to read and write control registers.
pub const control = @import("control.zig");

/// Processor state stored in the RFLAGS register.
pub const RFlags = @import("rflags.zig").RFlags;

/// Functions to read and write model specific registers.
pub const model_specific = @import("model_specific.zig");

/// Gets the current instruction pointer. Note that this is only approximate as it requires a few
/// instructions to execute.
pub fn readInstructionPointer() u64 {
    return asm ("lea (%%rip), %[ret]"
        : [ret] "=r" (-> u64)
    );
}

test "" {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
