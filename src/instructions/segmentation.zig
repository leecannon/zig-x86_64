usingnamespace @import("../common.zig");

/// Reload code segment register.
///
/// Note this is special since we can not directly move
/// to %cs. Instead we push the new segment selector
/// and return value on the stack and use lretq
/// to reload cs and continue at 1:.
pub fn set_cs(sel: structures.gdt.SegmentSelector) void {
    asm volatile ("pushq %[sel]; leaq 1f(%%rip), %%rax; pushq %%rax; lretq; 1:"
        :
        : [sel] "ri" (@as(u64, sel.selector))
        : "rax", "memory"
    );
}

/// Reload stack segment register.
pub fn load_ss(sel: structures.gdt.SegmentSelector) void {
    asm volatile ("movw %[sel], %%ss"
        :
        : [sel] "r" (sel.selector)
        : "memory"
    );
}

/// Reload data segment register.
pub fn load_ds(sel: structures.gdt.SegmentSelector) void {
    asm volatile ("movw %[sel], %%ds"
        :
        : [sel] "r" (sel.selector)
        : "memory"
    );
}

/// Reload es segment register.
pub fn load_es(sel: structures.gdt.SegmentSelector) void {
    asm volatile ("movw %[sel], %%es"
        :
        : [sel] "r" (sel.selector)
        : "memory"
    );
}

/// Reload fs segment register.
pub fn load_fs(sel: structures.gdt.SegmentSelector) void {
    asm volatile ("movw %[sel], %%fs"
        :
        : [sel] "r" (sel.selector)
        : "memory"
    );
}

/// Reload gs segment register.
pub fn load_gs(sel: structures.gdt.SegmentSelector) void {
    asm volatile ("movw %[sel], %%gs"
        :
        : [sel] "r" (sel.selector)
        : "memory"
    );
}

/// Swap `KernelGsBase` MSR and `GsBase` MSR.
pub fn swap_gs() void {
    asm volatile ("swapgs"
        :
        :
        : "memory"
    );
}

/// Returns the current value of the code segment register.
pub fn get_cs() structures.gdt.SegmentSelector {
    const cs = asm ("mov %%cs, %[ret]"
        : [ret] "=r" (-> u16)
    );
    return structures.gdt.SegmentSelector{ .selector = cs };
}

test "" {
    std.testing.refAllDecls(@This());
}
