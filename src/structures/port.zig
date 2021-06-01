usingnamespace @import("../common.zig");

/// A u8 I/O port
pub const Portu8 = struct {
    port: u16,

    pub fn init(port: u16) Portu8 {
        return .{
            .port = port,
        };
    }

    /// Read from the port
    pub fn read(self: Portu8) u8 {
        return x86_64.instructions.port.readU8(self.port);
    }

    /// Write to the port
    pub fn write(self: Portu8, value: u8) void {
        x86_64.instructions.port.writeU8(self.port, value);
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A u16 I/O port
pub const Portu16 = struct {
    port: u16,

    pub fn init(port: u16) Portu16 {
        return .{
            .port = port,
        };
    }

    /// Read from the port
    pub fn read(self: Portu16) u16 {
        return x86_64.instructions.port.readU16(self.port);
    }

    /// Write to the port
    pub fn write(self: Portu16, value: u16) void {
        x86_64.instructions.port.writeU16(self.port, value);
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A u32 I/O port
pub const Portu32 = struct {
    port: u16,

    pub fn init(port: u16) Portu32 {
        return .{
            .port = port,
        };
    }

    /// Read from the port
    pub fn read(self: Portu32) u32 {
        return x86_64.instructions.port.readU32(self.port);
    }

    /// Write to the port
    pub fn write(self: Portu32, value: u32) void {
        x86_64.instructions.port.writeU32(self.port, value);
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
