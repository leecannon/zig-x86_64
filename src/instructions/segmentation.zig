usingnamespace @import("../common.zig");

/// Reload code segment register.
///
/// Note this is special since we can not directly move
/// to %cs. Instead we push the new segment selector
/// and return value on the stack and use lretq
/// to reload cs and continue at 1:.
pub inline fn setCs(sel: structures.gdt.SegmentSelector) void {
    asm volatile ("pushq %[sel]; leaq 1f(%%rip), %%rax; pushq %%rax; lretq; 1:"
        :
        : [sel] "ri" (@as(u64, sel.selector))
        : "rax", "memory"
    );
}

/// Reload stack segment register.
pub inline fn loadSs(sel: structures.gdt.SegmentSelector) void {
    asm volatile ("movw %[sel], %%ss"
        :
        : [sel] "r" (sel.selector)
        : "memory"
    );
}

/// Reload data segment register.
pub inline fn loadDs(sel: structures.gdt.SegmentSelector) void {
    asm volatile ("movw %[sel], %%ds"
        :
        : [sel] "r" (sel.selector)
        : "memory"
    );
}

/// Reload es segment register.
pub inline fn loadEs(sel: structures.gdt.SegmentSelector) void {
    asm volatile ("movw %[sel], %%es"
        :
        : [sel] "r" (sel.selector)
        : "memory"
    );
}

/// Reload fs segment register.
pub inline fn loadFs(sel: structures.gdt.SegmentSelector) void {
    asm volatile ("movw %[sel], %%fs"
        :
        : [sel] "r" (sel.selector)
        : "memory"
    );
}

/// Reload gs segment register.
pub inline fn loadGs(sel: structures.gdt.SegmentSelector) void {
    asm volatile ("movw %[sel], %%gs"
        :
        : [sel] "r" (sel.selector)
        : "memory"
    );
}

/// Swap `KernelGsBase` MSR and `GsBase` MSR.
pub inline fn swapGs() void {
    asm volatile ("swapgs"
        :
        :
        : "memory"
    );
}

/// Returns the current value of the code segment register.
pub inline fn getCs() structures.gdt.SegmentSelector {
    const cs = asm ("mov %%cs, %[ret]"
        : [ret] "=r" (-> u16)
    );
    return structures.gdt.SegmentSelector{ .selector = cs };
}

/// Writes the FS segment base address
///
/// ## Safety
///
/// If `CR4.fsgsbase` is not set, this instruction will throw an `#UD`.
///
/// The caller must ensure that this write operation has no unsafe side
/// effects, as the FS segment base address is often used for thread
/// local storage.
pub inline fn wrfsbase(value: u64) void {
    asm volatile ("wrfsbase %[val]"
        :
        : [val] "r" (value)
    );
}

/// Reads the FS segment base address
///
/// ## Safety
///
/// If `CR4.fsgsbase` is not set, this instruction will throw an `#UD`.
pub inline fn rdfsbase() u64 {
    return asm volatile ("rdfsbase %[ret]"
        : [ret] "=r" (-> u64)
    );
}

/// Writes the GS segment base address
///
/// ## Safety
///
/// If `CR4.fsgsbase` is not set, this instruction will throw an `#UD`.
///
/// The caller must ensure that this write operation has no unsafe side
/// effects, as the GS segment base address might be in use.
pub inline fn wrgsbase(value: u64) void {
    asm volatile ("wrgsbase %[val]"
        :
        : [val] "r" (value)
    );
}

/// Reads the GS segment base address
///
/// ## Safety
///
/// If `CR4.fsgsbase` is not set, this instruction will throw an `#UD`.
pub inline fn rdgsbase() u64 {
    return asm volatile ("rdgsbase %[ret]"
        : [ret] "=r" (-> u64)
    );
}

test "" {
    std.testing.refAllDecls(@This());
}
