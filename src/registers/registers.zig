/// Processor state stored in the RFLAGS register.
pub const rflags = @import("rflags.zig");

/// Functions to read and write control registers.
pub const control = @import("control.zig");

/// Functions to read and write model specific registers.
pub const model_specific = @import("model_specific.zig");

/// Gets the current instruction pointer. Note that this is only approximate as it requires a few
/// instructions to execute.
pub inline fn readRip() u64 {
    return asm volatile ("lea (%%rip), %[ret]"
        : [ret] "=r" (-> u64)
    );
}

test "" {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
