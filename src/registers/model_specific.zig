usingnamespace @import("../common.zig");

const SegmentSelector = structures.gdt.SegmentSelector;

pub const EferFlags = packed struct {
    /// Enables the `syscall` and `sysret` instructions.
    system_call_extensions: bool,

    _padding1_7: u7,

    /// Activates long mode, requires activating paging.
    long_mode_enable: bool,

    _padding9: bool,

    /// Indicates that long mode is active.
    long_mode_active: bool,

    /// Enables the no-execute page-protection feature.
    no_execute_enable: bool,

    /// Enables SVM extensions.
    secure_virtual_machine_enable: bool,

    /// Enable certain limit checks in 64-bit mode.
    long_mode_segment_limit_enable: bool,

    /// Enable the `fxsave` and `fxrstor` instructions to execute faster in 64-bit mode.
    fast_fxsave_fxrstor: bool,

    /// Changes how the `invlpg` instruction operates on TLB entries of upper-level entries.
    translation_cache_extension: bool,

    _padding_a: u16,
    _padding_b: u32,

    pub inline fn fromU64(value: u64) EferFlags {
        return @bitCast(EferFlags, value & NO_PADDING);
    }

    pub inline fn toU64(self: EferFlags) u64 {
        return @bitCast(u64, self) & NO_PADDING;
    }

    const NO_PADDING: u64 = @bitCast(u64, EferFlags{
        .system_call_extensions = true,
        ._padding1_7 = 0,
        .long_mode_enable = true,
        ._padding9 = false,
        .long_mode_active = true,
        .no_execute_enable = true,
        .secure_virtual_machine_enable = true,
        .long_mode_segment_limit_enable = true,
        .fast_fxsave_fxrstor = true,
        .translation_cache_extension = true,
        ._padding_a = 0,
        ._padding_b = 0,
    });

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "EferFlags" {
    std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(EferFlags));
    std.testing.expectEqual(@sizeOf(u64), @sizeOf(EferFlags));
}

/// The Extended Feature Enable Register.
pub const Efer = struct {
    const register: u32 = 0xC000_0080;

    /// Read the current EFER flags.
    pub inline fn read() EferFlags {
        return EferFlags.fromU64(readRaw());
    }

    /// Read the current raw EFER flags.
    pub inline fn readRaw() u64 {
        return readMsr(register);
    }

    /// Write the EFER flags.
    ///
    /// Does not preserve any bits, including reserved fields.
    pub inline fn writeRaw(flags: u64) void {
        writeMsr(register, flags);
    }

    /// Write the EFER flags, preserving reserved values.
    ///
    /// Preserves the value of reserved fields.
    pub fn write(flags: EferFlags) void {
        const old_value = readRaw();
        const reserved = old_value & ~EferFlags.NO_PADDING;
        const new_value = reserved | flags.toU64();
        writeRaw(new_value);
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

/// Syscall Register: STAR
pub const Star = struct {
    const register: u32 = 0xC000_0081;

    pub const ReadRawStruct = struct {
        /// The CS selector is set to this field + 16. SS.Sel is set to
        /// this field + 8. Because SYSRET always returns to CPL 3, the
        /// RPL bits 1:0 should be initialized to 11b.
        sysret: u16,
        /// This field is copied directly into CS.Sel. SS.Sel is set to
        ///  this field + 8. Because SYSCALL always switches to CPL 0, the RPL bits
        /// 33:32 should be initialized to 00b.
        syscall: u16,
    };

    /// Read the Ring 0 and Ring 3 segment bases.
    /// The remaining fields are ignored because they are not valid for long mode
    pub fn readRaw() ReadRawStruct {
        const value = readMsr(register);
        return ReadRawStruct{ .sysret = @intCast(u16, getBits(value, 48, 16)), .syscall = @intCast(u16, getBits(value, 32, 16)) };
    }

    pub const ReadStruct = struct {
        /// CS Selector SYSRET
        sysret_cs_sel: SegmentSelector,
        /// SS Selector SYSRET
        sysret_ss_sel: SegmentSelector,
        /// CS Selector SYSCALL
        syscall_cs_sel: SegmentSelector,
        /// SS Selector SYSCALL
        syscall_ss_sel: SegmentSelector,
    };

    /// Read the Ring 0 and Ring 3 segment bases.
    pub fn read() ReadStruct {
        const raw = readRaw();

        return ReadStruct{
            .sysret_cs_sel = SegmentSelector{ .selector = raw.sysret + 16 },
            .sysret_ss_sel = SegmentSelector{ .selector = raw.sysret + 8 },
            .syscall_cs_sel = SegmentSelector{ .selector = raw.syscall },
            .syscall_ss_sel = SegmentSelector{ .selector = raw.syscall + 8 },
        };
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
        setBits(&value, 48, 16, sysret);
        setBits(&value, 32, 16, syscall);
        writeMsr(register, value);
    }

    pub const WriteErrors = error{
        /// Sysret CS and SS is not offset by 8.
        InvlaidSysretOffset,
        /// Syscall CS and SS is not offset by 8.
        InvlaidSyscallOffset,
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
    pub fn write(cs_sysret: SegmentSelector, ss_sysret: SegmentSelector, cs_syscall: SegmentSelector, ss_syscall: SegmentSelector) WriteErrors!void {
        if (cs_sysret.selector - 16 != ss_sysret.selector - 8) {
            return WriteErrors.InvlaidSysretOffset;
        }

        if (cs_syscall.selector != ss_syscall.selector - 8) {
            return WriteErrors.InvlaidSyscallOffset;
        }

        if ((ss_sysret.getRpl() catch return WriteErrors.SysretNotRing3) != .Ring3) {
            return WriteErrors.SysretNotRing3;
        }

        if ((ss_syscall.getRpl() catch return WriteErrors.SyscallNotRing0) != .Ring0) {
            return WriteErrors.SyscallNotRing0;
        }

        writeRaw(ss_sysret.selector - 8, cs_syscall.selector);
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

/// Syscall Register: SFMASK
pub const SFMask = struct {
    const register: u32 = 0xC000_0084;

    /// Read to the SFMask register.
    /// The SFMASK register is used to specify which RFLAGS bits
    /// are cleared during a SYSCALL. In long mode, SFMASK is used
    /// to specify which RFLAGS bits are cleared when SYSCALL is
    /// executed. If a bit in SFMASK is set to 1, the corresponding
    /// bit in RFLAGS is cleared to 0. If a bit in SFMASK is cleared
    /// to 0, the corresponding rFLAGS bit is not modified.
    pub inline fn read() registers.rflags.RFlags {
        return registers.rflags.RFlags.fromU64(readMsr(register));
    }

    /// Write to the SFMask register.
    /// The SFMASK register is used to specify which RFLAGS bits
    /// are cleared during a SYSCALL. In long mode, SFMASK is used
    /// to specify which RFLAGS bits are cleared when SYSCALL is
    /// executed. If a bit in SFMASK is set to 1, the corresponding
    /// bit in RFLAGS is cleared to 0. If a bit in SFMASK is cleared
    /// to 0, the corresponding rFLAGS bit is not modified.
    pub inline fn write(value: registers.rflags.RFlags) void {
        writeMsr(register, value.toU64());
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

/// Syscall Register: LSTAR
/// This holds the target RIP of a syscall.
pub const LStar = constructVirtaddrRegister(0xC000_0082);

/// FS.Base Model Specific Register.
pub const FsBase = constructVirtaddrRegister(0xC000_0100);

/// GS.Base Model Specific Register.
pub const GsBase = constructVirtaddrRegister(0xC000_0101);

/// KernelGsBase Model Specific Register.
pub const KernelGsBase = constructVirtaddrRegister(0xC000_0102);

fn constructVirtaddrRegister(comptime reg: u32) type {
    return struct {
        const register: u32 = reg;

        /// Read the current register value.
        pub inline fn read() VirtAddr {
            return VirtAddr.init(readMsr(register));
        }

        /// Write a given virtual address to the register.
        pub inline fn write(addr: VirtAddr) void {
            writeMsr(register, addr.value);
        }

        test "" {
            std.testing.refAllDecls(@This());
        }
    };
}

fn readMsr(reg: u32) u64 {
    var high: u32 = undefined;
    var low: u32 = undefined;

    asm volatile ("rdmsr"
        : [low] "={eax}" (low),
          [high] "={edx}" (high)
        : [reg] "{ecx}" (reg)
        : "memory"
    );

    return (@as(u64, high) << 32) | @as(u64, low);
}

fn writeMsr(reg: u32, value: u64) void {
    var high: u32 = @truncate(u32, value >> 32);
    var low: u32 = @truncate(u32, value);

    asm volatile ("wrmsr"
        :
        : [reg] "{ecx}" (reg),
          [low] "{eax}" (low),
          [high] "{edx}" (high)
        : "memory"
    );
}

test "" {
    std.testing.refAllDecls(@This());
}
