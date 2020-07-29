/// Abstractions for page tables and other paging related structures.
pub const paging = @import("paging/paging.zig");

/// Types for accessing I/O ports.
pub const port = @import("port.zig");

/// Types for the Global Descriptor Table and segment selectors.
pub const gdt = @import("gdt.zig");

/// A struct describing a pointer to a descriptor table (GDT / IDT).
/// This is in a format suitable for giving to 'lgdt' or 'lidt'.
pub const DescriptorTablePointer = packed struct {
    /// Size of the DT.
    limit: u16,
    /// Pointer to the memory region containing the DT.
    base: u64,
};

test "DescriptorTablePointer" {
    const std = @import("std");
    std.testing.expectEqual(80, @bitSizeOf(DescriptorTablePointer));
    std.testing.expectEqual(10, @sizeOf(DescriptorTablePointer));
}

test "" {
    const std = @import("std");
    std.meta.refAllDecls(@This());
}
