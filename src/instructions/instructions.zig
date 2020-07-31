/// Enabling and disabling interrupts
pub const interrupts = @import("interrupts.zig");

/// Access to I/O ports
pub const port = @import("port.zig");

/// Support for build-in RNGs
pub const random = @import("random.zig");

/// Functions to load GDT, IDT, and TSS structures.
pub const tables = @import("tables.zig");

/// Provides functions to read and write segment registers.
pub const segmentation = @import("segmentation.zig");

/// Functions to flush the translation lookaside buffer (TLB).
pub const tlb = @import("tlb.zig");

/// Halts the CPU until the next interrupt arrives.
pub fn hlt() void {
    asm volatile ("hlt");
}

/// Emits a '[magic breakpoint](https://wiki.osdev.org/Bochs#Magic_Breakpoint)' instruction for the [Bochs](http://bochs.sourceforge.net/) CPU
/// emulator. Make sure to set `magic_break: enabled=1` in your `.bochsrc` file.
pub fn bochs_breakpoint() void {
    asm volatile ("xchgw %%bx, %%bx");
}

test "" {
    const std = @import("std");
    std.meta.refAllDecls(@This());
}
