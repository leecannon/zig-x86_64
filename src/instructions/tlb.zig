usingnamespace @import("../common.zig");

/// Invalidate the given address in the TLB using the `invlpg` instruction.
pub fn flush(addr: VirtAddr) void {
    asm volatile ("invlpg (%[addr])"
        :
        : [addr] "r" (addr.value)
        : "memory"
    );
}

/// Invalidate the TLB completely by reloading the CR3 register.
pub fn flush_all() void {
    registers.control.Cr3.write(registers.control.Cr3.read());
}

test "" {
    std.meta.refAllDecls(@This());
}
