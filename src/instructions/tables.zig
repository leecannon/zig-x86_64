usingnamespace @import("../common.zig");

/// Load a GDT.
///
/// Use the `x86_64.structures.gdt.GlobalDescriptorTable` struct for a high-level interface to loading a GDT.
pub inline fn lgdt(gdt: *const x86_64.structures.DescriptorTablePointer) void {
    asm volatile ("lgdt (%[gdt])"
        :
        : [gdt] "r" (gdt)
        : "memory"
    );
}

/// Load a IDT.
///
/// Use the `x86_64.structures.idt.InterruptDescriptorTable` struct for a high-level interface to loading a IDT.
pub inline fn lidt(idt: *const x86_64.structures.DescriptorTablePointer) void {
    asm volatile ("lidt (%[idt])"
        :
        : [idt] "r" (idt)
        : "memory"
    );
}

/// Get the address of the current IDT.
pub inline fn sidt() x86_64.structures.DescriptorTablePointer {
    var idt: x86_64.structures.DescriptorTablePointer = undefined;
    asm volatile ("sidt (%[idt])"
        :
        : [idt] "r" (idt)
    );
    return idt;
}

/// Load the task state register using the `ltr` instruction.
pub inline fn loadTss(sel: x86_64.structures.gdt.SegmentSelector) void {
    asm volatile ("ltr %[sel]"
        :
        : [sel] "r" (sel.value)
    );
}

comptime {
    std.testing.refAllDecls(@This());
}
