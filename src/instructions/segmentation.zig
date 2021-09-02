usingnamespace @import("../common.zig");

/// Returns the current value of the code segment register.
pub fn getCs() x86_64.structures.gdt.SegmentSelector {
    return .{
        .value = asm ("mov %%cs, %[ret]"
            : [ret] "=r" (-> u16),
        ),
    };
}

/// Reload code segment register.
///
/// The segment base and limit are unused in 64-bit mode. Only the L (long), D
/// (default operation size), and DPL (descriptor privilege-level) fields of the
/// descriptor are recognized. So changing the segment register can be used to
/// change privilege level or enable/disable long mode.
///
/// Note this is special since we cannot directly move to [`CS`]. Instead we
/// push the new segment selector and return value on the stack and use
/// `retfq` to reload [`CS`] and continue at the end of our function.
pub fn setCs(sel: x86_64.structures.gdt.SegmentSelector) void {
    asm volatile ("pushq %[sel]; leaq 1f(%%rip), %%rax; pushq %%rax; lretq; 1:"
        :
        : [sel] "ri" (@as(u64, sel.value)),
        : "rax", "memory"
    );
}

/// Returns the current value of the stack segment register.
pub fn getSs() x86_64.structures.gdt.SegmentSelector {
    return .{
        .value = asm ("mov %%ss, %[ret]"
            : [ret] "=r" (-> u16),
        ),
    };
}

/// Reload stack segment register.
///
/// Entirely unused in 64-bit mode; setting the segment register does nothing.
/// However, in ring 3, the SS register still has to point to a valid
/// [`Descriptor`] (it cannot be zero). This means a user-mode read/write
/// segment descriptor must be present in the GDT.
///
/// This register is also set by the `syscall`/`sysret` and
/// `sysenter`/`sysexit` instructions (even on 64-bit transitions). This is to
/// maintain symmetry with 32-bit transitions where setting SS actually will
/// actually have an effect.
pub fn setSs(sel: x86_64.structures.gdt.SegmentSelector) void {
    asm volatile ("movw %[sel], %%ss"
        :
        : [sel] "r" (sel.value),
        : "memory"
    );
}

/// Returns the current value of the data segment register.
pub fn getDs() x86_64.structures.gdt.SegmentSelector {
    return .{
        .value = asm ("mov %%ds, %[ret]"
            : [ret] "=r" (-> u16),
        ),
    };
}

/// Reload data segment register.
///
/// Entirely unused in 64-bit mode; setting the segment register does nothing.
pub fn setDs(sel: x86_64.structures.gdt.SegmentSelector) void {
    asm volatile ("movw %[sel], %%ds"
        :
        : [sel] "r" (sel.value),
        : "memory"
    );
}

/// Returns the current value of the es segment register.
pub fn getEs() x86_64.structures.gdt.SegmentSelector {
    return .{
        .value = asm ("mov %%es, %[ret]"
            : [ret] "=r" (-> u16),
        ),
    };
}

/// Reload es segment register.
///
/// Entirely unused in 64-bit mode; setting the segment register does nothing.
pub fn setEs(sel: x86_64.structures.gdt.SegmentSelector) void {
    asm volatile ("movw %[sel], %%es"
        :
        : [sel] "r" (sel.value),
        : "memory"
    );
}

/// Returns the current value of the fs segment register.
pub fn getFs() x86_64.structures.gdt.SegmentSelector {
    return .{
        .value = asm ("mov %%fs, %[ret]"
            : [ret] "=r" (-> u16),
        ),
    };
}

/// Reload fs segment register.
pub fn setFs(sel: x86_64.structures.gdt.SegmentSelector) void {
    asm volatile ("movw %[sel], %%fs"
        :
        : [sel] "r" (sel.value),
        : "memory"
    );
}

/// Returns the current value of the gs segment register.
pub fn getGs() x86_64.structures.gdt.SegmentSelector {
    return .{
        .value = asm ("mov %%gs, %[ret]"
            : [ret] "=r" (-> u16),
        ),
    };
}

/// Reload gs segment register.
pub fn setGs(sel: x86_64.structures.gdt.SegmentSelector) void {
    asm volatile ("movw %[sel], %%gs"
        :
        : [sel] "r" (sel.value),
        : "memory"
    );
}

/// Swap `KernelGsBase` MSR and `GsBase` MSR.
pub fn swapGs() void {
    asm volatile ("swapgs" ::: "memory");
}

/// Reads the fs segment base address
///
/// ## Exceptions
///
/// If `CR4.fsgsbase` is not set, this instruction will throw an `#UD`.
pub fn readFsBase() u64 {
    return asm ("rdfsbase %[ret]"
        : [ret] "=r" (-> u64),
    );
}

/// Writes the fs segment base address
///
/// ## Exceptions
///
/// If `CR4.fsgsbase` is not set, this instruction will throw an `#UD`.
///
/// The caller must ensure that this write operation has no unsafe side
/// effects, as the fs segment base address is often used for thread
/// local storage.
pub fn writeFsBase(value: u64) void {
    asm volatile ("wrfsbase %[val]"
        :
        : [val] "r" (value),
    );
}

/// Reads the gs segment base address
///
/// ## Exceptions
///
/// If `CR4.fsgsbase` is not set, this instruction will throw an `#UD`.
pub fn readGsBase() u64 {
    return asm ("rdgsbase %[ret]"
        : [ret] "=r" (-> u64),
    );
}

/// Writes the gs segment base address
///
/// ## Exceptions
///
/// If `CR4.fsgsbase` is not set, this instruction will throw an `#UD`.
///
/// The caller must ensure that this write operation has no unsafe side
/// effects, as the gs segment base address might be in use.
pub fn writeGsBase(value: u64) void {
    asm volatile ("wrgsbase %[val]"
        :
        : [val] "r" (value),
    );
}

comptime {
    std.testing.refAllDecls(@This());
}
