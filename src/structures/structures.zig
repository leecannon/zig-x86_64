/// Abstractions for page tables and other paging related structures.
pub const paging = @import("paging/paging.zig");

/// Types for the Global Descriptor Table and segment selectors.
pub const gdt = @import("gdt.zig");

/// Types for accessing I/O ports.
pub const port = @import("port.zig");

/// Provides a type for the task state segment structure.
pub const tss = @import("tss.zig");

/// Provides types for the Interrupt Descriptor Table and its entries.
pub const idt = @import("idt.zig");

const x86_64 = @import("../index.zig");
const bitjuggle = @import("bitjuggle");
const std = @import("std");

/// A struct describing a pointer to a descriptor table (GDT / IDT).
/// This is in a format suitable for giving to 'lgdt' or 'lidt'.
pub const DescriptorTablePointer = packed struct {
    /// bytes of the DT.
    limit: u16,

    /// Pointer to the memory region containing the DT.
    base: x86_64.VirtAddr,

    test {
        std.testing.refAllDecls(@This());
        try std.testing.expectEqual(@bitSizeOf(u16) + @bitSizeOf(u64), @bitSizeOf(DescriptorTablePointer));
        try std.testing.expectEqual(@sizeOf(u16) + @sizeOf(u64), @sizeOf(DescriptorTablePointer));
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
