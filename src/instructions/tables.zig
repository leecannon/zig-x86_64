usingnamespace @import("../common.zig");

/// Load a GDT.
///
/// Use the `structures.gdt.GlobalDescriptorTable` struct for a high-level interface to loading a GDT.
pub fn lgdt(gdt: *const structures.DescriptorTablePointer) void {
    asm volatile ("lgdt (%[gdt])"
        :
        : [gdt] "r" (gdt)
        : "memory"
    );
}

/// Load a IDT.
///
/// Use the `structures.idt.InterruptDescriptorTable` struct for a high-level interface to loading a IDT.
pub fn lidt(idt: *const structures.DescriptorTablePointer) void {
    asm volatile ("lidt (%[idt])"
        :
        : [idt] "r" (idt)
        : "memory"
    );
}

/// Load the task state register using the `ltr` instruction.
pub fn loadTss(sel: structures.gdt.SegmentSelector) void {
    asm volatile ("ltr %[sel]"
        :
        : [sel] "r" (sel.value)
    );
}

test "" {
    std.testing.refAllDecls(@This());
}
