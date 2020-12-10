usingnamespace @import("../common.zig");

/// Returns whether interrupts are enabled.
pub inline fn areEnabled() bool {
    return registers.rflags.RFlags.read().interrupt_flag;
}

/// Enable interrupts.
///
/// This is a wrapper around the `sti` instruction.
pub inline fn enable() void {
    asm volatile ("sti");
}

/// Disable interrupts.
///
/// This is a wrapper around the `cli` instruction.
pub inline fn disable() void {
    asm volatile ("cli");
}

/// Run a function with disabled interrupts.
///
/// Run the given function, disabling interrupts before running it (if they aren't already disabled).
/// Afterwards, interrupts are enabling again if they were enabled before.
///
/// If you have other `enable` and `disable` calls _within_ the function, things may not work as expected.
pub fn withoutInterrupts(comptime func: fn () void) void {
    const enabled = areEnabled();

    if (enabled) disable();
    defer {
        if (enabled) enable();
    }

    func();
}

/// Run a function with disabled interrupts.
///
/// Run the given function, disabling interrupts before running it (if they aren't already disabled).
/// Afterwards, interrupts are enabling again if they were enabled before.
///
/// If you have other `enable` and `disable` calls _within_ the function, things may not work as expected.
pub fn withoutInterruptsArgument(comptime arg_type: type, comptime func: fn (arg_type) void, argument: arg_type) void {
    const enabled = areEnabled();

    if (enabled) disable();
    defer {
        if (enabled) enable();
    }

    func(argument);
}

/// Run a function with disabled interrupts and return its result.
///
/// Run the given function and return its result, disabling interrupts before running it (if they aren't already disabled).
/// Afterwards, interrupts are enabling again if they were enabled before.
///
/// If you have other `enable` and `disable` calls _within_ the function, things may not work as expected.
pub fn withoutInterruptsReturn(comptime ret_type: type, comptime func: fn () ret_type) ret_type {
    const enabled = areEnabled();

    if (enabled) disable();
    defer {
        if (enabled) enable();
    }

    return func();
}

/// Run a function with disabled interrupts and return its result.
///
/// Run the given function and return its result, disabling interrupts before running it (if they aren't already disabled).
/// Afterwards, interrupts are enabling again if they were enabled before.
///
/// If you have other `enable` and `disable` calls _within_ the function, things may not work as expected.
pub fn withoutInterruptsArgumentReturn(comptime arg_type: type, comptime ret_type: type, comptime func: fn (arg_type) ret_type, argument: arg_type) ret_type {
    const enabled = areEnabled();

    if (enabled) disable();
    defer {
        if (enabled) enable();
    }

    return func(argument);
}

/// Atomically enable interrupts and put the CPU to sleep
///
/// Executes the `sti; hlt` instruction sequence. Since the `sti` instruction
/// keeps interrupts disabled until after the immediately following
/// instruction (called "interrupt shadow"), no interrupt can occur between the
/// two instructions. (One exception to this are non-maskable interrupts; this
/// is explained below.)
///
/// This function is useful to put the CPU to sleep without missing interrupts
/// that occur immediately before the `hlt` instruction
///
/// ## Non-maskable Interrupts
///
/// On some processors, the interrupt shadow of `sti` does not apply to
/// non-maskable interrupts (NMIs). This means that an NMI can occur between
/// the `sti` and `hlt` instruction, with the result that the CPU is put to
/// sleep even though a new interrupt occured.
///
/// To work around this, it is recommended to check in the NMI handler if
/// the interrupt occured between `sti` and `hlt` instructions. If this is the
/// case, the handler should increase the instruction pointer stored in the
/// interrupt stack frame so that the `hlt` instruction is skipped.
///
/// See <http://lkml.iu.edu/hypermail/linux/kernel/1009.2/01406.html> for more
/// information.
pub inline fn enableAndHlt() void {
    asm volatile ("sti; hlt");
}

/// Cause a breakpoint exception by invoking the `int3` instruction.
pub inline fn int3() void {
    asm volatile ("int3");
}

/// Generate a software interrupt by invoking the `int` instruction.
pub inline fn softwareInterrupt(comptime num: usize) void {
    asm volatile ("int %[num]"
        :
        : [num] "N" (num)
    );
}

test "" {
    std.testing.refAllDecls(@This());
}
