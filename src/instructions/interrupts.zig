usingnamespace @import("../common.zig");

/// Returns whether interrupts are enabled.
pub inline fn are_enabled() bool {
    return registers.rflags.RFlags.read_raw().INTERRUPT_FLAG;
}

/// Enable interrupts.
///
/// This is a wrapper around the `sti` instruction.
pub inline fn enable() void {
    asm volatile("sti");
}

/// Disable interrupts.
///
/// This is a wrapper around the `cli` instruction.
pub inline fn disable() void {
    asm volatile("cli");
}

/// Run a function with disabled interrupts.
///
/// Run the given function, disabling interrupts before running it (if they aren't already disabled).
/// Afterwards, interrupts are enabling again if they were enabled before.
///
/// If you have other `enable` and `disable` calls _within_ the function, things may not work as expected.
pub inline fn without_interupts(comptime func: fn() void) void {
    const enabled = are_enabled();
    
    if (enabled) disable();
    defer {
        if (enabled) enable();
    }
    
    func();
}

/// Run a function with disabled interrupts and return its result.
///
/// Run the given function and return its result, disabling interrupts before running it (if they aren't already disabled).
/// Afterwards, interrupts are enabling again if they were enabled before.
///
/// If you have other `enable` and `disable` calls _within_ the function, things may not work as expected.
pub inline fn without_interupts_return(comptime ret_type: type, comptime func: fn() ret_type) ret_type {
    const enabled = are_enabled();
    
    if (enabled) disable();
    defer {
        if (enabled) enable();
    }
    
    return func();
}
