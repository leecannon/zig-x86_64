/// Functions to read and write control registers.
pub const control = @import("control.zig");

/// Access to various extended system registers
pub const xcontrol = @import("xcontrol.zig");

/// Processor state stored in the RFLAGS register.
pub const RFlags = @import("rflags.zig").RFlags;

/// Functions to read and write model specific registers.
pub const model_specific = @import("model_specific.zig");

const x86_64 = @import("../index.zig");
const bitjuggle = @import("bitjuggle");
const std = @import("std");

/// Gets the current instruction pointer. Note that this is only approximate as it requires a few
/// instructions to execute.
pub inline fn readInstructionPointer() x86_64.VirtAddr {
    return x86_64.VirtAddr.initUnchecked(asm ("lea (%%rip), %[ret]"
        : [ret] "=r" (-> u64),
    ));
}

comptime {
    std.testing.refAllDecls(@This());
}
