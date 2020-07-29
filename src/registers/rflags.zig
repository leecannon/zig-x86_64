usingnamespace @import("../common.zig");

pub const RFlags = packed struct {
    /// Set by hardware if last arithmetic operation generated a carry out of the
    /// most-significant bit of the result.
    CARRY_FLAG: bool,
    _padding1: bool,
    /// Set by hardware if last result has an even number of 1 bits (only for some operations)
    PARITY_FLAG: bool,
    _padding3: bool,
    /// Set by hardware if last arithmetic operation generated a carry ouf of bit 3 of the
    /// result.
    AUXILIARY_CARRY_FLAG: bool,
    _padding5: bool,
    /// Set by hardware if last arithmetic operation resulted in a zero value.
    ZERO_FLAG: bool,
    /// Set by hardware if last arithmetic operation resulted in a negative value.
    SIGN_FLAG: bool,
    /// Enable single-step mode for debugging.
    TRAP_FLAG: bool,
    /// Enable interrupts.
    INTERRUPT_FLAG: bool,
    /// Determines the order in which strings are processed.
    DIRECTION_FLAG: bool,
    /// Set by hardware to indicate that the sign bit of the result of the last signed integer
    /// operation differs from the source operands.
    OVERFLOW_FLAG: bool,
    /// The low bit of the I/O Privilege Level field.
    ///
    /// Specifies the privilege level required for executing I/O address-space instructions.
    IOPL_LOW: bool,
    /// The high bit of the I/O Privilege Level field.
    ///
    /// Specifies the privilege level required for executing I/O address-space instructions.
    IOPL_HIGH: bool,
    /// Used by `iret` in hardware task switch mode to determine if current task is nested.
    NESTED_TASK: bool,
    _padding15: bool,
    /// Allows to restart an instruction following an instrucion breakpoint.
    RESUME_FLAG: bool,
    /// Enable the virtual-8086 mode.
    VIRTUAL_8086_MODE: bool,
    /// Enable automatic alignment checking if CR0.AM is set. Only works if CPL is 3.
    ALIGNMENT_CHECK: bool,
    /// Virtual image of the INTERRUPT_FLAG bit.
    ///
    /// Used when virtual-8086 mode extensions (CR4.VME) or protected-mode virtual
    /// interrupts (CR4.PVI) are activated.
    VIRTUAL_INTERRUP: bool,
    /// Indicates that an external, maskable interrupt is pending.
    ///
    /// Used when virtual-8086 mode extensions (CR4.VME) or protected-mode virtual
    /// interrupts (CR4.PVI) are activated.
    VIRTUAL_INTERRUPT_PENDING: bool,
    /// Processor feature identification flag.
    ///
    /// If this flag is modifiable, the CPU supports CPUID.
    ID: bool,

    // I can't wait for better bitfields in Zig... this is a mess
    _padding_a: u10,
    _padding_b: u32,

    pub fn from_u64(value: u64) RFlags {
        return @bitCast(RFlags, value);
    }

    pub inline fn to_u64(self: RFlags) u64 {
        return @bitCast(u64, self);
    }

    /// Returns the raw current value of the RFLAGS register.
    pub fn read_raw() RFlags {
        const raw = asm ("pushfq; popq %[ret]"
            : [ret] "=r" (-> u64)
            :
            : "memory"
        );
        return from_u64(raw);
    }

    /// Writes the RFLAGS register.
    ///
    /// Does not preserve any bits, including reserved bits.
    pub inline fn write_raw(self: RFlags) void {
        asm volatile ("pushq %[val]; popfq"
            :
            : [val] "r" (self.to_u64())
            : "memory", "flags"
        );
    }
};

test "RFlags" {
    std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(RFlags));
    std.testing.expectEqual(@sizeOf(u64), @sizeOf(RFlags));

    const a = RFlags.from_u64(10);
    const b = a.to_u64();

    std.testing.expectEqual(@as(u64, 10), b);
}

test "" {
    std.meta.refAllDecls(@This());
}
