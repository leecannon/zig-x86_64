usingnamespace @import("../common.zig");

/// Load a GDT.
///
/// Use the `structures.gdt.GlobalDescriptorTable` struct for a high-level interface to loading a GDT.
pub inline fn lgdt(gdt: *structures.DescriptorTablePointer) void {
    asm volatile ("lgdt (%[gdt])"
        :
        : [gdt] "r" (gdt)
        : "memory"
    );
}

/// Load a IDT.
///
/// Use the `structures.idt.InterruptDescriptorTable` struct for a high-level interface to loading a IDT.
pub inline fn lidt(idt: *structures.DescriptorTablePointer) void {
    asm volatile ("lidt (%[gdt])"
        :
        : [idt] "r" (idt)
        : "memory"
    );
}

/// Load the task state register using the `ltr` instruction.
pub inline fn load_tss(sel: structures.gdt.SegmentSelector) void {
    asm volatile ("ltr %[sel]"
        :
        : [sel] "r" (sel.selector)
    );
}
