usingnamespace @import("../common.zig");

/// A u8 I/O port
pub const Portu8 = Port(.u8);

/// A u16 I/O port
pub const Portu16 = Port(.u16);

/// A u32 I/O port
pub const Portu32 = Port(.u32);

const PortBitness = enum {
    u8,
    u16,
    u32,
};

fn Port(comptime portBitness: PortBitness) type {
    const int_type = switch (portBitness) {
        .u8 => u8,
        .u16 => u16,
        .u32 => u32,
    };

    return struct {
        const Self = @This();

        port: u16,

        pub fn init(port: u16) callconv(.Inline) Self {
            return .{
                .port = port,
            };
        }

        /// Read from the port
        pub fn read(self: Self) callconv(.Inline) int_type {
            return switch (portBitness) {
                .u8 => x86_64.instructions.port.readU8(self.port),
                .u16 => x86_64.instructions.port.readU16(self.port),
                .u32 => x86_64.instructions.port.readU32(self.port),
            };
        }

        /// Write to the port
        pub fn write(self: Self, value: int_type) callconv(.Inline) void {
            switch (portBitness) {
                .u8 => x86_64.instructions.port.writeU8(self.port, value),
                .u16 => x86_64.instructions.port.writeU16(self.port, value),
                .u32 => x86_64.instructions.port.writeU32(self.port, value),
            }
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };
}

comptime {
    std.testing.refAllDecls(@This());
}
