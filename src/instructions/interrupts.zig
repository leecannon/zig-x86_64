const x86_64 = @import("../index.zig");
const bitjuggle = @import("bitjuggle");
const std = @import("std");

pub const EnsureNoInterrupts = struct {
    enabled: bool,

    pub fn start() EnsureNoInterrupts {
        return .{
            .enabled = areEnabled(),
        };
    }

    pub fn end(self: EnsureNoInterrupts) void {
        if (self.enabled) enable();
    }
};

/// Returns whether interrupts are enabled.
pub fn areEnabled() bool {
    return x86_64.registers.RFlags.read().interrupt;
}

/// Enable interrupts.
///
/// This is a wrapper around the `sti` instruction.
pub fn enable() void {
    asm volatile ("sti");
}

/// Disable interrupts.
///
/// This is a wrapper around the `cli` instruction.
pub fn disable() void {
    asm volatile ("cli");
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
pub fn enableAndHlt() void {
    asm volatile ("sti; hlt");
}

pub fn disableAndHlt() noreturn {
    while (true) {
        asm volatile ("cli; hlt");
    }
}

/// Cause a breakpoint exception by invoking the `int3` instruction.
pub fn int3() void {
    asm volatile ("int3");
}

/// Generate a software interrupt by invoking the `int` instruction.
pub fn softwareInterrupt(comptime num: usize) void {
    asm volatile ("int %[num]"
        :
        : [num] "N" (num),
    );
}

comptime {
    std.testing.refAllDecls(@This());
}
