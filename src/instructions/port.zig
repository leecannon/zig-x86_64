usingnamespace @import("../common.zig");

pub fn readU8(port: u16) callconv(.Inline) u8 {
    return asm volatile ("inb %[port],%[ret]"
        : [ret] "={al}" (-> u8)
        : [port] "N{dx}" (port)
    );
}

pub fn readU16(port: u16) callconv(.Inline) u16 {
    return asm volatile ("inw %[port],%[ret]"
        : [ret] "={al}" (-> u16)
        : [port] "N{dx}" (port)
    );
}

pub fn readU32(port: u16) callconv(.Inline) u32 {
    return asm volatile ("inl %[port],%[ret]"
        : [ret] "={eax}" (-> u32)
        : [port] "N{dx}" (port)
    );
}

pub fn writeU8(port: u16, value: u8) callconv(.Inline) void {
    asm volatile ("outb %[value],%[port]"
        :
        : [value] "{al}" (value),
          [port] "N{dx}" (port)
    );
}

pub fn writeU16(port: u16, value: u16) callconv(.Inline) void {
    asm volatile ("outw %[value],%[port]"
        :
        : [value] "{al}" (value),
          [port] "N{dx}" (port)
    );
}

pub fn writeU32(port: u16, value: u32) callconv(.Inline) void {
    asm volatile ("outl %[value],%[port]"
        :
        : [value] "{eax}" (value),
          [port] "N{dx}" (port)
    );
}

comptime {
    std.testing.refAllDecls(@This());
}
