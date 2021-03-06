/// Types for UART serial ports.
pub const serial_port = @import("serial_port.zig");

/// A simple pic8259 implementation
pub const pic8259 = @import("pic8259.zig");

comptime {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
