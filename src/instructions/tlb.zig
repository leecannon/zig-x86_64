usingnamespace @import("../common.zig");

/// Invalidate the given address in the TLB using the `invlpg` instruction.
pub inline fn flush(addr: VirtAddr) void {
    asm volatile ("invlpg (%[addr])"
        :
        : [addr] "r" (addr.value)
        : "memory"
    );
}

// TODO: Waiting on PhysFrame
// /// Invalidate the TLB completely by reloading the CR3 register.
// pub inline fn flush_all() void {
//
// }

test "" {
    std.meta.refAllDecls(@This());
}
