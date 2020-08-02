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
    VIRTUAL_INTERRUPT: bool,
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
        return @bitCast(RFlags, value & NO_PADDING);
    }

    pub fn to_u64(self: RFlags) u64 {
        return @bitCast(u64, self) & NO_PADDING;
    }

    const NO_PADDING: u64 = @bitCast(u64, RFlags{
        .CARRY_FLAG = true,
        ._padding1 = false,
        .PARITY_FLAG = true,
        ._padding3 = false,
        .AUXILIARY_CARRY_FLAG = true,
        ._padding5 = false,
        .ZERO_FLAG = true,
        .SIGN_FLAG = true,
        .TRAP_FLAG = true,
        .INTERRUPT_FLAG = true,
        .DIRECTION_FLAG = true,
        .OVERFLOW_FLAG = true,
        .IOPL_HIGH = true,
        .IOPL_LOW = true,
        .NESTED_TASK = true,
        ._padding15 = false,
        .RESUME_FLAG = true,
        .VIRTUAL_8086_MODE = true,
        .ALIGNMENT_CHECK = true,
        .VIRTUAL_INTERRUPT = true,
        .VIRTUAL_INTERRUPT_PENDING = true,
        .ID = true,
        ._padding_a = 0,
        ._padding_b = 0,
    });

    /// Returns the current value of the RFLAGS register.
    ///
    /// Drops any unknown bits.
    pub fn read() RFlags {
        return RFlags.from_u64(read_raw());
    }

    /// Returns the raw current value of the RFLAGS register.
    pub fn read_raw() u64 {
        return asm ("pushfq; popq %[ret]"
            : [ret] "=r" (-> u64)
            :
            : "memory"
        );
    }

    /// Writes the RFLAGS register, preserves reserved bits.
    pub fn write(self: RFlags) void {
        const old_value = read_raw();
        const reserved = old_value & ~NO_PADDING;
        const new_value = reserved | self.to_u64();
        write_raw(new_value);
    }

    /// Writes the RFLAGS register.
    ///
    /// Does not preserve any bits, including reserved bits.
    pub fn write_raw(value: u64) void {
        asm volatile ("pushq %[val]; popfq"
            :
            : [val] "r" (value)
            : "memory", "flags"
        );
    }
};

test "RFlags" {
    std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(RFlags));
    std.testing.expectEqual(@sizeOf(u64), @sizeOf(RFlags));

    var a = RFlags.from_u64(0);
    a.PARITY_FLAG = true;
    std.testing.expectEqual(@as(u64, 1 << 2), a.to_u64());
}

test "" {
    std.meta.refAllDecls(@This());
}
