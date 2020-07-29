usingnamespace @import("../common.zig");

pub inline fn read_u8(port: u16) u8 {
    return asm volatile ("inb %[port],%[ret]"
        : [ret] "={al}" (-> u8)
        : [port] "N{dx}" (port)
    );
}

pub inline fn read_u16(port: u16) u16 {
    return asm volatile ("inw %[port],%[ret]"
        : [ret] "={al}" (-> u16)
        : [port] "N{dx}" (port)
    );
}

pub inline fn read_u32(port: u16) u32 {
    return asm volatile ("inl %[port],%[ret]"
        : [ret] "={eax}" (-> u32)
        : [port] "N{dx}" (port)
    );
}

pub inline fn write_u8(port: u16, value: u8) void {
    asm volatile ("outb %[value],%[port]"
        :
        : [value] "{al}" (value),
          [port] "N{dx}" (port)
    );
}

pub inline fn write_u16(port: u16, value: u16) void {
    asm volatile ("outw %[value],%[port]"
        :
        : [value] "{al}" (value),
          [port] "N{dx}" (port)
    );
}

pub inline fn write_u32(port: u16, value: u32) void {
    asm volatile ("outl %[value],%[port]"
        :
        : [value] "{eax}" (value),
          [port] "N{dx}" (port)
    );
}

test "" {
    std.meta.refAllDecls(@This());
}
