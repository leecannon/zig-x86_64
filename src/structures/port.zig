usingnamespace @import("../common.zig");

/// A u8 I/O port
pub const Port_u8 = Port(.u8);

/// A u16 I/O port
pub const Port_u16 = Port(.u16);

/// A u32 I/O port
pub const Port_u32 = Port(.u32);

const PortBitness = enum {
    u8,
    u16,
    u32,
};

fn Port(comptime bitness: PortBitness) type {
    const int_type = switch (bitness) {
        .u8 => u8,
        .u16 => u16,
        .u32 => u32,
    };

    return struct {
        const Self = @This();
        port: u16,

        /// Creates an I/O port with the given port number
        pub inline fn new(port: u16) Self {
            return Self{ .port = port };
        }

        /// Read from the port
        pub inline fn read(self: Self) int_type {
            return switch (bitness) {
                .u8 => instructions.port.read_u8(self.port),
                .u16 => instructions.port.read_u16(self.port),
                .u32 => instructions.port.read_u32(self.port),
            };
        }

        /// Write to the port
        pub inline fn write(self: Self, value: int_type) void {
            switch (bitness) {
                .u8 => instructions.port.write_u8(self.port, value),
                .u16 => instructions.port.write_u16(self.port, value),
                .u32 => instructions.port.write_u32(self.port, value),
            }
        }
    };
}
