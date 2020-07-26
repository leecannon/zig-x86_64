usingnamespace @import("../common.zig");

pub const Port = struct {
    port: u16,

    pub inline fn new(port: u16) Port {
        return Port{ .port = port };
    }

    pub inline fn port_read_u8(self: Port) u8 {
        return asm volatile ("inb %[port],%[ret]"
            : [ret] "={al}" (-> u8)
            : [port] "N{dx}" (self.port)
        );
    }

    pub inline fn port_read_u16(self: Port) u16 {
        return asm volatile ("inw %[port],%[ret]"
            : [ret] "={al}" (-> u16)
            : [port] "N{dx}" (self.port)
        );
    }

    pub inline fn port_read_u32(self: Port) u32 {
        return asm volatile ("inl %[port],%[ret]"
            : [ret] "={eax}" (-> u32)
            : [port] "N{dx}" (self.port)
        );
    }

    pub inline fn port_write_u8(self: Port, value: u8) void {
        asm volatile ("outb %[value],%[port]"
            :
            : [value] "{al}" (value),
              [port] "N{dx}" (self.port)
        );
    }

    pub inline fn port_write_u16(self: Port, value: u16) void {
        asm volatile ("outw %[value],%[port]"
            :
            : [value] "{al}" (value),
              [port] "N{dx}" (self.port)
        );
    }

    pub inline fn port_write_u32(self: Port, value: u32) void {
        asm volatile ("outl %[value],%[port]"
            :
            : [value] "{eax}" (value),
              [port] "N{dx}" (self.port)
        );
    }
};
