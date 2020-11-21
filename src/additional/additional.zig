/// Various kernel-space locks.
pub const lock = @import("lock.zig");

/// Types for UART serial ports.
pub const serial_port = @import("serial_port.zig");

test "" {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
