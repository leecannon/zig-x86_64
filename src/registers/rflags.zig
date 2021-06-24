usingnamespace @import("../common.zig");

/// The RFLAGS register.
pub const RFlags = packed struct {
    /// Set by hardware if last arithmetic operation generated a carry out of the
    /// most-significant bit of the result.
    carry: bool,
    z_reserved1: bool,

    /// Set by hardware if last result has an even number of 1 bits (only for some operations).
    parity: bool,
    z_reserved3: bool,

    /// Set by hardware if last arithmetic operation generated a carry ouf of bit 3 of the
    /// result.
    auxiliary_carry: bool,
    z_reserved5: bool,

    /// Set by hardware if last arithmetic operation resulted in a zero value.
    zero: bool,

    /// Set by hardware if last arithmetic operation resulted in a negative value.
    sign: bool,

    /// Enable single-step mode for debugging.
    trap: bool,

    /// Enable interrupts.
    interrupt: bool,

    /// Determines the order in which strings are processed.
    direction: bool,

    /// Set by hardware to indicate that the sign bit of the result of the last signed integer
    /// operation differs from the source operands.
    overflow: bool,

    /// Specifies the privilege level required for executing I/O address-space instructions.
    iopl: u2,

    /// Used by `iret` in hardware task switch mode to determine if current task is nested.
    nested: bool,
    z_reserved15: bool,

    /// Allows to restart an instruction following an instrucion breakpoint.
    @"resume": bool,

    /// Enable the virtual-8086 mode.
    virtual_8086: bool,

    /// Enable automatic alignment checking if CR0.AM is set. Only works if CPL is 3.
    alignment_check: bool,

    /// Virtual image of the INTERRUPT_FLAG bit.
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

    z_reserved22_31: u10,
    z_reserved32_63: u32,

    /// Returns the current value of the RFLAGS register.
    pub fn read() RFlags {
        return RFlags.fromU64(readRaw());
    }

    /// Returns the raw current value of the RFLAGS register.
    fn readRaw() u64 {
        return asm ("pushfq; popq %[ret]"
            : [ret] "=r" (-> u64)
            :
            : "memory"
        );
    }

    /// Writes the RFLAGS register, preserves reserved bits.
    pub fn write(self: RFlags) void {
        writeRaw(self.toU64() | (readRaw() & ALL_RESERVED));
    }

    /// Writes the RFLAGS register.
    /// Does not preserve any bits
    fn writeRaw(value: u64) void {
        asm volatile ("pushq %[val]; popfq"
            :
            : [val] "r" (value)
            : "memory", "flags"
        );
    }

    const ALL_RESERVED: u64 = blk: {
        var flags = std.mem.zeroes(RFlags);
        flags.z_reserved1 = true;
        flags.z_reserved15 = true;
        flags.z_reserved22_31 = std.math.maxInt(u10);
        flags.z_reserved3 = true;
        flags.z_reserved32_63 = std.math.maxInt(u32);
        flags.z_reserved5 = true;
        break :blk @bitCast(u64, flags);
    };

    const ALL_NOT_RESERVED: u64 = ~ALL_RESERVED;

    pub fn fromU64(value: u64) RFlags {
        return @bitCast(RFlags, value & ALL_NOT_RESERVED);
    }

    pub fn toU64(self: RFlags) u64 {
        return @bitCast(u64, self) & ALL_NOT_RESERVED;
    }

    pub fn format(value: RFlags, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        return formatWithoutFields(
            value,
            options,
            writer,
            &.{"z_reserved"},
        );
    }

    test {
        try std.testing.expectEqual(@as(usize, 64), @bitSizeOf(RFlags));
        try std.testing.expectEqual(@as(usize, 8), @sizeOf(RFlags));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
