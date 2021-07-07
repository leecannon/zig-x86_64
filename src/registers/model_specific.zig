usingnamespace @import("../common.zig");

/// The Extended Feature Enable Register.
pub const Efer = packed struct {

    /// Enables the `syscall` and `sysret` instructions.
    system_call_extensions: bool,

    z_reserved1_7: u7,

    /// Activates long mode, requires activating paging.
    long_mode_enable: bool,

    z_reserved9: bool,

    /// Indicates that long mode is active.
    long_mode_active: bool,

    /// Enables the no-execute page-protection feature.
    no_execute_enable: bool,

    /// Enables SVM extensions.
    secure_virtual_machine_enable: bool,

    /// Enable certain limit checks in 64-bit mode.
    long_mode_segment_limit: bool,

    /// Enable the `fxsave` and `fxrstor` instructions to execute faster in 64-bit mode.
    fast_fxsave_fxrstor: bool,

    /// Changes how the `invlpg` instruction operates on TLB entries of upper-level entries.
    translation_cache_extension: bool,

    z_reserved16_31: u16,
    z_reserved32_63: u32,

    /// Read the current EFER flags.
    pub fn read() Efer {
        return Efer.fromU64(REGISTER.read());
    }

    /// Write the EFER flags, preserving reserved values.
    ///
    /// Preserves the value of reserved fields.
    pub fn write(self: Efer) void {
        REGISTER.write(self.toU64() | (REGISTER.read() & ALL_RESERVED));
    }

    const REGISTER = Msr(0xC000_0080);

    const ALL_RESERVED: u64 = blk: {
        var flags = std.mem.zeroes(Efer);
        flags.z_reserved1_7 = std.math.maxInt(u7);
        flags.z_reserved9 = true;
        flags.z_reserved16_31 = std.math.maxInt(u16);
        flags.z_reserved32_63 = std.math.maxInt(u32);
        break :blk @bitCast(u64, flags);
    };

    const ALL_NOT_RESERVED: u64 = ~ALL_RESERVED;

    pub fn fromU64(value: u64) Efer {
        return @bitCast(Efer, value & ALL_NOT_RESERVED);
    }

    pub fn toU64(self: Efer) u64 {
        return @bitCast(u64, self) & ALL_NOT_RESERVED;
    }

    pub fn format(value: Efer, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        return formatWithoutFields(
            value,
            options,
            writer,
            &.{"z_reserved"},
        );
    }

    test {
        try std.testing.expectEqual(@as(usize, 64), @bitSizeOf(Efer));
        try std.testing.expectEqual(@as(usize, 8), @sizeOf(Efer));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// FS.Base Model Specific Register.
pub const FsBase = struct {
    const REGISTER = Msr(0xC000_0100);

    /// Read the current FsBase register.
    pub fn read() x86_64.VirtAddr {
        // We use unchecked here as we assume that the write function did not write an invalid address
        return x86_64.VirtAddr.initUnchecked(REGISTER.read());
    }

    /// Write a given virtual address to the FS.Base register.
    pub fn write(addr: x86_64.VirtAddr) void {
        REGISTER.write(addr.value);
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// GS.Base Model Specific Register.
pub const GsBase = struct {
    const REGISTER = Msr(0xC000_0101);

    /// Read the current GsBase register.
    pub fn read() x86_64.VirtAddr {
        // We use unchecked here as we assume that the write function did not write an invalid address
        return x86_64.VirtAddr.initUnchecked(REGISTER.read());
    }

    /// Write a given virtual address to the GS.Base register.
    pub fn write(addr: x86_64.VirtAddr) void {
        REGISTER.write(addr.value);
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// KernelGsBase Model Specific Register.
pub const KernelGsBase = struct {
    const REGISTER = Msr(0xC000_0102);

    /// Read the current KernelGsBase register.
    pub fn read() x86_64.VirtAddr {
        // We use unchecked here as we assume that the write function did not write an invalid address
        return x86_64.VirtAddr.initUnchecked(REGISTER.read());
    }

    /// Write a given virtual address to the KernelGsBase register.
    pub fn write(addr: x86_64.VirtAddr) void {
        REGISTER.write(addr.value);
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Syscall Register: STAR
pub const Star = struct {
    sysretCsSelector: x86_64.structures.gdt.SegmentSelector,
    sysretSsSelector: x86_64.structures.gdt.SegmentSelector,
    syscallCsSelector: x86_64.structures.gdt.SegmentSelector,
    syscallSsSelector: x86_64.structures.gdt.SegmentSelector,

    const REGISTER = Msr(0xC000_0081);

    /// Read the Ring 0 and Ring 3 segment bases.
    pub fn read() Star {
        const raw = readRaw();
        return .{
            .sysretCsSelector = .{ .value = raw[0] + 16 },
            .sysretSsSelector = .{ .value = raw[0] + 8 },
            .syscallCsSelector = .{ .value = raw[1] },
            .syscallSsSelector = .{ .value = raw[1] + 8 },
        };
    }

    /// Read the Ring 0 and Ring 3 segment bases.
    /// The remaining fields are ignored because they are
    /// not valid for long mode.
    ///
    /// # Returns
    /// - Item 0 (SYSRET): The CS selector is set to this field + 16. SS.Sel is set to
    /// this field + 8. Because SYSRET always returns to CPL 3, the
    /// RPL bits 1:0 should be initialized to 11b.
    /// - Item 1 (SYSCALL): This field is copied directly into CS.Sel. SS.Sel is set to
    ///  this field + 8. Because SYSCALL always switches to CPL 0, the RPL bits
    /// 33:32 should be initialized to 00b.
    pub fn readRaw() [2]u16 {
        const val = REGISTER.read();
        return [2]u16{
            bitjuggle.getBits(val, 48, 16),
            bitjuggle.getBits(val, 32, 16),
        };
    }

    pub const WriteError = error{
        /// Sysret CS and SS is not offset by 8.
        InvalidSysretOffset,
        /// Syscall CS and SS is not offset by 8.
        InvalidSyscallOffset,
        /// Sysret's segment must be a Ring3 segment.
        SysretNotRing3,
        /// Syscall's segment must be a Ring0 segment.
        SyscallNotRing0,
    };

    /// Write the Ring 0 and Ring 3 segment bases.
    /// The remaining fields are ignored because they are
    /// not valid for long mode.
    /// This function will fail if the segment selectors are
    /// not in the correct offset of each other or if the
    /// segment selectors do not have correct privileges.
    pub fn write(self: Star) WriteError!void {
        if (self.sysretCsSelector.value - 16 != self.sysretSsSelector.value - 8) {
            return WriteError.InvalidSysretOffset;
        }
        if (self.syscallCsSelector.value != self.syscallSsSelector.value - 8) {
            return WriteError.InvalidSyscallOffset;
        }
        if (self.sysretSsSelector.getRpl() != .Ring3) {
            return WriteError.SysretNotRing3;
        }
        if (self.syscallSsSelector.getRpl() != .Ring0) {
            return WriteError.SyscallNotRing0;
        }

        writeRaw(self.sysretSsSelector.value - 8, self.syscallSsSelector.value);
    }

    /// Write the Ring 0 and Ring 3 segment bases.
    /// The remaining fields are ignored because they are
    /// not valid for long mode.
    ///
    /// # Parameters
    /// - sysret: The CS selector is set to this field + 16. SS.Sel is set to
    /// this field + 8. Because SYSRET always returns to CPL 3, the
    /// RPL bits 1:0 should be initialized to 11b.
    /// - syscall: This field is copied directly into CS.Sel. SS.Sel is set to
    ///  this field + 8. Because SYSCALL always switches to CPL 0, the RPL bits
    /// 33:32 should be initialized to 00b.
    pub fn writeRaw(sysret: u16, syscall: u16) void {
        var value: u64 = 0;
        bitjuggle.setBits(&value, 48, 16, sysret);
        bitjuggle.setBits(&value, 32, 16, syscall);
        REGISTER.write(value);
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Syscall Register: LSTAR
pub const LStar = struct {
    const REGISTER = Msr(0xC000_0082);

    /// Read the current LStar register.
    /// This holds the target RIP of a syscall.
    pub fn read() x86_64.VirtAddr {
        // We use unchecked here as we assume that the write function did not write an invalid address
        return x86_64.VirtAddr.initUnchecked(REGISTER.read());
    }

    /// Write a given virtual address to the LStar register.
    /// This holds the target RIP of a syscall.
    pub fn write(addr: x86_64.VirtAddr) void {
        REGISTER.write(addr.value);
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Syscall Register: SFMask
pub const SFMask = struct {
    const REGISTER = Msr(0xC000_0084);

    /// Read to the SFMask register.
    /// The SFMASK register is used to specify which RFLAGS bits
    /// are cleared during a SYSCALL. In long mode, SFMASK is used
    /// to specify which RFLAGS bits are cleared when SYSCALL is
    /// executed. If a bit in SFMASK is set to 1, the corresponding
    /// bit in RFLAGS is cleared to 0. If a bit in SFMASK is cleared
    /// to 0, the corresponding rFLAGS bit is not modified.
    pub fn read() x86_64.registers.RFlags {
        return x86_64.registers.RFlags.fromU64(REGISTER.read());
    }

    /// Write to the SFMask register.
    /// The SFMASK register is used to specify which RFLAGS bits
    /// are cleared during a SYSCALL. In long mode, SFMASK is used
    /// to specify which RFLAGS bits are cleared when SYSCALL is
    /// executed. If a bit in SFMASK is set to 1, the corresponding
    /// bit in RFLAGS is cleared to 0. If a bit in SFMASK is cleared
    /// to 0, the corresponding rFLAGS bit is not modified.
    pub fn write(value: x86_64.registers.RFlags) void {
        REGISTER.write(value.toU64());
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

fn Msr(comptime register: u32) type {
    return struct {
        pub inline fn read() u64 {
            var high: u32 = undefined;
            var low: u32 = undefined;

            asm volatile ("rdmsr"
                : [low] "={eax}" (low),
                  [high] "={edx}" (high)
                : [reg] "{ecx}" (register)
                : "memory"
            );

            return (@as(u64, high) << 32) | @as(u64, low);
        }

        pub inline fn write(value: u64) void {
            asm volatile ("wrmsr"
                :
                : [reg] "{ecx}" (register),
                  [low] "{eax}" (@truncate(u32, value)),
                  [high] "{edx}" (@truncate(u32, value >> 32))
                : "memory"
            );
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };
}

comptime {
    std.testing.refAllDecls(@This());
}
