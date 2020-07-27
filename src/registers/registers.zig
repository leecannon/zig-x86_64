pub const rflags = @import("rflags.zig");
pub const control = @import("control.zig");

pub fn read_rip() u64 {
    return asm volatile ("lea (%%rip), %[ret]"
        : [ret] "=r" (-> u64)
    );
}
