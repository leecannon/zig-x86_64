usingnamespace @import("../common.zig");

usingnamespace instructions.port;
usingnamespace structures.port;

pub const COMPort = enum {
    COM1,
    COM2,
    COM3,
    COM4,
};

fn com_port_to_port(com_port: COMPort) u16 {
    return switch (com_port) {
        .COM1 => 0x3F8,
        .COM2 => 0x2F8,
        .COM3 => 0x3E8,
        .COM4 => 0x2E8,
    };
}

pub const BaudRate = enum {
    Baud115200,
    Baud57600,
    Baud38400,
    Baud28800,
};

fn baud_rate_to_divisor(baud_rate: BaudRate) u8 {
    return switch (baud_rate) {
        .Baud115200 => 1,
        .Baud57600 => 2,
        .Baud38400 => 3,
        .Baud28800 => 4,
    };
}

/// Represents a UART SerialPort with support for formated output
pub const LockedSerialPort = BuildSerialPort(true);

/// Represents a UART SerialPort with support for formated output
/// *** Warning - No locking version
pub const SerialPort = BuildSerialPort(false);

fn BuildSerialPort(comptime useLock: bool) type {
    const lockType = if (comptime useLock) additional.lock.KernelSpinLock else void;

    return struct {
        const Self = @This();

        data_port: Portu8,
        line_status_port: Portu8,
        lock: lockType,

        pub fn init(com_port: COMPort, baud_rate: BaudRate) Self {
            const data_port = com_port_to_port(com_port);

            // Disable interupts
            write_u8(data_port + 1, 0x00);

            // Set Baudrate
            write_u8(data_port + 3, 0x80);
            write_u8(data_port, baud_rate_to_divisor(baud_rate));
            write_u8(data_port + 1, 0x00);

            // 8 bits, no parity, one stop bit
            write_u8(data_port + 3, 0x03);

            // Enable FIFO
            write_u8(data_port + 2, 0xC7);

            // Mark data terminal ready
            write_u8(data_port + 4, 0x0B);

            // Enable interupts
            write_u8(data_port + 1, 0x01);

            return Self{
                .data_port = Portu8.init(data_port),
                .line_status_port = Portu8.init(data_port + 5),
                .lock = if (comptime useLock) additional.lock.KernelSpinLock.init() else {},
            };
        }

        /// Write a single char
        inline fn write_char(self: LockedSerialPort, char: u8) void {
            while (self.line_status_port.read() & 0x20 == 0) {}
            self.data_port.write(char);
        }

        /// Write a string
        pub fn write_str(self: *LockedSerialPort, str: []const u8) void {
            if (comptime useLock) {
                const token = self.lock.lock();
                defer token.unlock();
                for (str) |char| self.write_char(char);
            } else {
                for (str) |char| self.write_char(char);
            }
        }

        /// Write formated output
        pub inline fn write_format(self: *LockedSerialPort, comptime fmt: []const u8, args: anytype) void {
            self.writer().print(fmt, args) catch return;
        }

        pub const Writer = std.io.Writer(*LockedSerialPort, error{}, writer_impl);

        /// The impl function driving the `std.io.Writer`
        fn writer_impl(self: *LockedSerialPort, bytes: []const u8) error{}!usize {
            self.write_str(bytes);
            return bytes.len;
        }

        /// Create a `std.io.Writer` for this serial port
        pub inline fn writer(self: *LockedSerialPort) Writer {
            return .{ .context = self };
        }

        test "" {
            std.testing.refAllDecls(@This());
        }
    };
}

test "" {
    std.testing.refAllDecls(@This());
}
