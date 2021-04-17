usingnamespace @import("../common.zig");

/// Load a GDT.
///
/// Use the `x86_64.structures.gdt.GlobalDescriptorTable` struct for a high-level interface to loading a GDT.
pub fn lgdt(gdt: *const x86_64.structures.DescriptorTablePointer) callconv(.Inline) void {
    asm volatile ("lgdt (%[gdt])"
        :
        : [gdt] "r" (gdt)
        : "memory"
    );
}

/// Load a IDT.
///
/// Use the `x86_64.structures.idt.InterruptDescriptorTable` struct for a high-level interface to loading a IDT.
pub fn lidt(idt: *const x86_64.structures.DescriptorTablePointer) callconv(.Inline) void {
    asm volatile ("lidt (%[idt])"
        :
        : [idt] "r" (idt)
        : "memory"
    );
}

/// Load the task state register using the `ltr` instruction.
pub fn loadTss(sel: x86_64.structures.gdt.SegmentSelector) callconv(.Inline) void {
    asm volatile ("ltr %[sel]"
        :
        : [sel] "r" (sel.value)
    );
}

comptime {
    std.testing.refAllDecls(@This());
}
