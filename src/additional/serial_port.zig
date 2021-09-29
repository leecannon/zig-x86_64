const x86_64 = @import("../index.zig");
const std = @import("std");

const Portu8 = x86_64.structures.port.Portu8;
const writeU8 = x86_64.instructions.port.writeU8;

const DATA_READY: u8 = 1;
const OUTPUT_READY: u8 = 1 << 5;

pub const COMPort = enum {
    COM1,
    COM2,
    COM3,
    COM4,

    fn toPort(com_port: COMPort) u16 {
        return switch (com_port) {
            .COM1 => 0x3F8,
            .COM2 => 0x2F8,
            .COM3 => 0x3E8,
            .COM4 => 0x2E8,
        };
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const BaudRate = enum {
    Baud115200,
    Baud57600,
    Baud38400,
    Baud28800,

    fn toDivisor(baud_rate: BaudRate) u8 {
        return switch (baud_rate) {
            .Baud115200 => 1,
            .Baud57600 => 2,
            .Baud38400 => 3,
            .Baud28800 => 4,
        };
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const SerialPort = struct {
    z_data_port: Portu8,
    z_line_status_port: Portu8,

    /// Initalize the serial port at `com_port` with the baud rate `baud_rate` 
    pub fn init(com_port: COMPort, baud_rate: BaudRate) SerialPort {
        const data_port_number = com_port.toPort();

        // Disable interrupts
        writeU8(data_port_number + 1, 0x00);

        // Set Baudrate
        writeU8(data_port_number + 3, 0x80);
        writeU8(data_port_number, baud_rate.toDivisor());
        writeU8(data_port_number + 1, 0x00);

        // 8 bits, no parity, one stop bit
        writeU8(data_port_number + 3, 0x03);

        // Enable FIFO
        writeU8(data_port_number + 2, 0xC7);

        // Mark data terminal ready
        writeU8(data_port_number + 4, 0x0B);

        // Enable interupts
        writeU8(data_port_number + 1, 0x01);

        return .{
            .z_data_port = Portu8.init(data_port_number),
            .z_line_status_port = Portu8.init(data_port_number + 5),
        };
    }

    fn waitForOutputReady(self: SerialPort) void {
        while (self.z_line_status_port.read() & OUTPUT_READY == 0) {
            x86_64.instructions.pause();
        }
    }

    fn waitForInputReady(self: SerialPort) void {
        while (self.z_line_status_port.read() & DATA_READY == 0) {
            x86_64.instructions.pause();
        }
    }

    fn sendByte(self: SerialPort, data: u8) void {
        switch (data) {
            8, 0x7F => {
                self.waitForOutputReady();
                self.z_data_port.write(8);
                self.waitForOutputReady();
                self.z_data_port.write(' ');
                self.waitForOutputReady();
                self.z_data_port.write(8);
            },
            else => {
                self.waitForOutputReady();
                self.z_data_port.write(data);
            },
        }
    }

    pub fn readByte(self: SerialPort) u8 {
        self.waitForInputReady();
        return self.z_data_port.read();
    }

    pub const Writer = std.io.Writer(SerialPort, error{}, writerImpl);
    pub fn writer(self: SerialPort) Writer {
        return .{ .context = self };
    }

    /// The impl function driving the `std.io.Writer`
    fn writerImpl(self: SerialPort, bytes: []const u8) error{}!usize {
        for (bytes) |char| {
            self.sendByte(char);
        }
        return bytes.len;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
