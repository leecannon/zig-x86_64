usingnamespace @import("../common.zig");

pub const RFlags = packed struct {
    /// Set by hardware if last arithmetic operation generated a carry out of the
    /// most-significant bit of the result.
    carry_flag: bool,
    _padding1: bool,
    /// Set by hardware if last result has an even number of 1 bits (only for some operations)
    parity_flag: bool,
    _padding3: bool,
    /// Set by hardware if last arithmetic operation generated a carry ouf of bit 3 of the
    /// result.
    auxiliary_carry_flag: bool,
    _padding5: bool,
    /// Set by hardware if last arithmetic operation resulted in a zero value.
    zero_flag: bool,
    /// Set by hardware if last arithmetic operation resulted in a negative value.
    sign_flag: bool,
    /// Enable single-step mode for debugging.
    trap_flag: bool,
    /// Enable interrupts.
    interrupt_flag: bool,
    /// Determines the order in which strings are processed.
    direction_flag: bool,
    /// Set by hardware to indicate that the sign bit of the result of the last signed integer
    /// operation differs from the source operands.
    overflow_flag: bool,
    /// The low bit of the I/O Privilege Level field.
    ///
    /// Specifies the privilege level required for executing I/O address-space instructions.
    iopl_low: bool,
    /// The high bit of the I/O Privilege Level field.
    ///
    /// Specifies the privilege level required for executing I/O address-space instructions.
    iopl_high: bool,
    /// Used by `iret` in hardware task switch mode to determine if current task is nested.
    nested_task: bool,
    _padding15: bool,
    /// Allows to restart an instruction following an instrucion breakpoint.
    resume_flag: bool,
    /// Enable the virtual-8086 mode.
    virtual_8086_mode: bool,
    /// Enable automatic alignment checking if CR0.AM is set. Only works if CPL is 3.
    alignment_check: bool,
    /// Virtual image of the interrupt_flag bit.
    ///
    /// Used when virtual-8086 mode extensions (CR4.VME) or protected-mode virtual
    /// interrupts (CR4.PVI) are activated.
    virtual_interrupt: bool,
    /// Indicates that an external, maskable interrupt is pending.
    ///
    /// Used when virtual-8086 mode extensions (CR4.VME) or protected-mode virtual
    /// interrupts (CR4.PVI) are activated.
    virtual_interrupt_pending: bool,
    /// Processor feature identification flag.
    ///
    /// If this flag is modifiable, the CPU supports CPUID.
    id: bool,

    // I can't wait for better bitfields in Zig... this is a mess
    _padding_a: u10,
    _padding_b: u32,

    pub inline fn fromU64(value: u64) RFlags {
        return @bitCast(RFlags, value & NO_PADDING);
    }

    pub inline fn toU64(self: RFlags) u64 {
        return @bitCast(u64, self) & NO_PADDING;
    }

    const NO_PADDING: u64 = @bitCast(u64, RFlags{
        .carry_flag = true,
        ._padding1 = false,
        .parity_flag = true,
        ._padding3 = false,
        .auxiliary_carry_flag = true,
        ._padding5 = false,
        .zero_flag = true,
        .sign_flag = true,
        .trap_flag = true,
        .interrupt_flag = true,
        .direction_flag = true,
        .overflow_flag = true,
        .iopl_high = true,
        .iopl_low = true,
        .nested_task = true,
        ._padding15 = false,
        .resume_flag = true,
        .virtual_8086_mode = true,
        .alignment_check = true,
        .virtual_interrupt = true,
        .virtual_interrupt_pending = true,
        .id = true,
        ._padding_a = 0,
        ._padding_b = 0,
    });

    /// Returns the current value of the RFLAGS register.
    ///
    /// Drops any unknown bits.
    pub inline fn read() RFlags {
        return RFlags.fromU64(readRaw());
    }

    /// Returns the raw current value of the RFLAGS register.
    pub inline fn readRaw() u64 {
        return asm ("pushfq; popq %[ret]"
            : [ret] "=r" (-> u64)
            :
            : "memory"
        );
    }

    /// Writes the RFLAGS register, preserves reserved bits.
    pub fn write(self: RFlags) void {
        const old_value = readRaw();
        const reserved = old_value & ~NO_PADDING;
        const new_value = reserved | self.toU64();
        writeRaw(new_value);
    }

    /// Writes the RFLAGS register.
    ///
    /// Does not preserve any bits, including reserved bits.
    pub inline fn writeRaw(value: u64) void {
        asm volatile ("pushq %[val]; popfq"
            :
            : [val] "r" (value)
            : "memory", "flags"
        );
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "RFlags" {
    std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(RFlags));
    std.testing.expectEqual(@sizeOf(u64), @sizeOf(RFlags));

    var a = RFlags.fromU64(0);
    a.parity_flag = true;
    std.testing.expectEqual(@as(u64, 1 << 2), a.toU64());
}

test "" {
    std.testing.refAllDecls(@This());
}
