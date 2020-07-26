usingnamespace @import("../common.zig");

pub const interrupts = @import("interrupts.zig");
pub const port = @import("port.zig");
pub const random = @import("random.zig");

/// Halts the CPU until the next interrupt arrives.
pub inline fn hlt() void {
    asm volatile ("hlt");
}

/// Emits a '[magic breakpoint](https://wiki.osdev.org/Bochs#Magic_Breakpoint)' instruction for the [Bochs](http://bochs.sourceforge.net/) CPU
/// emulator. Make sure to set `magic_break: enabled=1` in your `.bochsrc` file.
pub inline fn bochs_breakpoint() void {
    asm volatile ("xchgw %%bx, %%bx");
}
