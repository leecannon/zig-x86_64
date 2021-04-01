usingnamespace @import("../common.zig");

/// The RFLAGS register.
pub const RFlags = struct {
    value: u64,

    /// Returns the current value of the RFLAGS register.
    ///
    /// Drops any unknown bits.
    pub fn read() RFlags {
        return .{ .value = readRaw() & ALL };
    }

    /// Returns the raw current value of the RFLAGS register.
    pub fn readRaw() u64 {
        return asm ("pushfq; popq %[ret]"
            : [ret] "=r" (-> u64)
            :
            : "memory"
        );
    }

    /// Writes the RFLAGS register, preserves reserved bits.
    pub fn write(self: RFlags) void {
        writeRaw(self.value | (readRaw() & NOT_ALL));
    }

    /// Writes the RFLAGS register.
    ///
    /// Does not preserve any bits, including reserved bits. any values, including reserved fields.
    pub fn writeRaw(value: u64) void {
        asm volatile ("pushq %[val]; popfq"
            :
            : [val] "r" (value)
            : "memory", "flags"
        );
    }

    pub const ALL: u64 =
        ID | VIRTUAL_INTERRUPT_PENDING | VIRTUAL_INTERRUPT | ALIGNMENT_CHECK | VIRTUAL_8086_MODE |
        RESUME_FLAG | NESTED_TASK | IOPL_HIGH | IOPL_LOW | OVERFLOW_FLAG | DIRECTION_FLAG |
        INTERRUPT_FLAG | TRAP_FLAG | SIGN_FLAG | ZERO_FLAG | AUXILIARY_CARRY_FLAG |
        PARITY_FLAG | CARRY_FLAG;

    pub const NOT_ALL: u64 = ~ALL;

    /// Processor feature identification flag.
    ///
    /// If this flag is modifiable, the CPU supports CPUID.
    pub const ID: u64 = 1 << 21;
    pub const NOT_ID: u64 = ~ID;

    /// Indicates that an external, maskable interrupt is pending.
    ///
    /// Used when virtual-8086 mode extensions (CR4.VME) or protected-mode virtual
    /// interrupts (CR4.PVI) are activated.
    pub const VIRTUAL_INTERRUPT_PENDING: u64 = 1 << 20;
    pub const NOT_VIRTUAL_INTERRUPT_PENDING: u64 = ~VIRTUAL_INTERRUPT_PENDING;

    /// Virtual image of the INTERRUPT_FLAG bit.
    ///
    /// Used when virtual-8086 mode extensions (CR4.VME) or protected-mode virtual
    /// interrupts (CR4.PVI) are activated.
    pub const VIRTUAL_INTERRUPT: u64 = 1 << 19;
    pub const NOT_VIRTUAL_INTERRUPT: u64 = ~VIRTUAL_INTERRUPT;

    /// Enable automatic alignment checking if CR0.AM is set. Only works if CPL is 3.
    pub const ALIGNMENT_CHECK: u64 = 1 << 18;
    pub const NOT_ALIGNMENT_CHECK: u64 = ~ALIGNMENT_CHECK;

    /// Enable the virtual-8086 mode.
    pub const VIRTUAL_8086_MODE: u64 = 1 << 17;
    pub const NOT_VIRTUAL_8086_MODE: u64 = ~VIRTUAL_8086_MODE;

    /// Allows to restart an instruction following an instrucion breakpoint.
    pub const RESUME_FLAG: u64 = 1 << 16;
    pub const NOT_RESUME_FLAG: u64 = ~RESUME_FLAG;

    /// Used by `iret` in hardware task switch mode to determine if current task is nested.
    pub const NESTED_TASK: u64 = 1 << 14;
    pub const NOT_NESTED_TASK: u64 = ~NESTED_TASK;

    /// The high bit of the I/O Privilege Level field.
    ///
    /// Specifies the privilege level required for executing I/O address-space instructions.
    pub const IOPL_HIGH: u64 = 1 << 13;
    pub const NOT_IOPL_HIGH: u64 = ~IOPL_HIGH;

    /// The low bit of the I/O Privilege Level field.
    ///
    /// Specifies the privilege level required for executing I/O address-space instructions.
    pub const IOPL_LOW: u64 = 1 << 12;
    pub const NOT_IOPL_LOW: u64 = ~IOPL_LOW;

    /// Set by hardware to indicate that the sign bit of the result of the last signed integer
    /// operation differs from the source operands.
    pub const OVERFLOW_FLAG: u64 = 1 << 11;
    pub const NOT_OVERFLOW_FLAG: u64 = ~OVERFLOW_FLAG;

    /// Determines the order in which strings are processed.
    pub const DIRECTION_FLAG: u64 = 1 << 10;
    pub const NOT_DIRECTION_FLAG: u64 = ~DIRECTION_FLAG;

    /// Enable interrupts.
    pub const INTERRUPT_FLAG: u64 = 1 << 9;
    pub const NOT_INTERRUPT_FLAG: u64 = ~INTERRUPT_FLAG;

    /// Enable single-step mode for debugging.
    pub const TRAP_FLAG: u64 = 1 << 8;
    pub const NOT_TRAP_FLAG: u64 = ~TRAP_FLAG;

    /// Set by hardware if last arithmetic operation resulted in a negative value.
    pub const SIGN_FLAG: u64 = 1 << 7;
    pub const NOT_SIGN_FLAG: u64 = ~SIGN_FLAG;

    /// Set by hardware if last arithmetic operation resulted in a zero value.
    pub const ZERO_FLAG: u64 = 1 << 6;
    pub const NOT_ZERO_FLAG: u64 = ~ZERO_FLAG;

    /// Set by hardware if last arithmetic operation generated a carry ouf of bit 3 of the
    /// result.
    pub const AUXILIARY_CARRY_FLAG: u64 = 1 << 4;
    pub const NOT_AUXILIARY_CARRY_FLAG: u64 = ~AUXILIARY_CARRY_FLAG;

    /// Set by hardware if last result has an even number of 1 bits (only for some operations).
    pub const PARITY_FLAG: u64 = 1 << 2;
    pub const NOT_PARITY_FLAG: u64 = ~PARITY_FLAG;

    /// Set by hardware if last arithmetic operation generated a carry out of the
    /// most-significant bit of the result.
    pub const CARRY_FLAG: u64 = 1;
    pub const NOT_CARRY_FLAG: u64 = ~CARRY_FLAG;

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
