usingnamespace @import("../common.zig");

const SegmentSelector = structures.gdt.SegmentSelector;

pub const EferFlags = packed struct {
    /// Enables the `syscall` and `sysret` instructions.
    SYSTEM_CALL_EXTENSIONS: bool,

    _padding1_7: u7,

    /// Activates long mode, requires activating paging.
    LONG_MODE_ENABLE: bool,

    _padding9: bool,

    /// Indicates that long mode is active.
    LONG_MODE_ACTIVE: bool,

    /// Enables the no-execute page-protection feature.
    NO_EXECUTE_ENABLE: bool,

    /// Enables SVM extensions.
    SECURE_VIRTUAL_MACHINE_ENABLE: bool,

    /// Enable certain limit checks in 64-bit mode.
    LONG_MODE_SEGMENT_LIMIT_ENABLE: bool,

    /// Enable the `fxsave` and `fxrstor` instructions to execute faster in 64-bit mode.
    FAST_FXSAVE_FXRSTOR: bool,

    /// Changes how the `invlpg` instruction operates on TLB entries of upper-level entries.
    TRANSLATION_CACHE_EXTENSION: bool,

    _padding_a: u16,
    _padding_b: u32,

    pub fn from_u64(value: u64) EferFlags {
        return @bitCast(EferFlags, value).zero_padding();
    }

    pub fn to_u64(self: EferFlags) u64 {
        return @bitCast(u64, self.zero_padding());
    }

    pub fn zero_padding(self: EferFlags) EferFlags {
        var result: EferFlags = @bitCast(EferFlags, @as(u64, 0));

        result.SYSTEM_CALL_EXTENSIONS = self.SYSTEM_CALL_EXTENSIONS;
        result.LONG_MODE_ENABLE = self.LONG_MODE_ENABLE;
        result.LONG_MODE_ACTIVE = self.LONG_MODE_ACTIVE;
        result.NO_EXECUTE_ENABLE = self.NO_EXECUTE_ENABLE;
        result.SECURE_VIRTUAL_MACHINE_ENABLE = self.SECURE_VIRTUAL_MACHINE_ENABLE;
        result.LONG_MODE_SEGMENT_LIMIT_ENABLE = self.LONG_MODE_SEGMENT_LIMIT_ENABLE;
        result.FAST_FXSAVE_FXRSTOR = self.FAST_FXSAVE_FXRSTOR;
        result.TRANSLATION_CACHE_EXTENSION = self.TRANSLATION_CACHE_EXTENSION;

        return result;
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
    pub fn read() EferFlags {
        return EferFlags.from_u64(read_msr(register));
    }

    /// Write the EFER flags.
    ///
    /// Does not preserve any bits, including reserved fields.
    pub fn write_raw(flags: u64) void {
        write_msr(register, flags);
    }

    pub const UpdateEferFunc = fn (*EferFlags) void;

    /// Update EFER flags.
    pub fn update(func: UpdateEferFunc) void {
        var flags = read();
        func(&flags);
        write_raw(flags.to_u64());
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
    pub fn read_raw() ReadRawStruct {
        const value = read_msr(register);
        return StarHelper{ .sysret = get_bits(value, 48, 16), .syscall = get_bits(value, 32, 16) };
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
        const raw = read_raw();

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
    pub fn write_raw(sysret: u16, syscall: u16) void {
        var value: u64 = 0;
        set_bits(&value, 48, 16, sysret);
        set_bits(&value, 32, 16, syscall);
        write_msr(register, value);
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

        if (ss_sysret.get_rpl() != .Ring3) {
            return WriteErrors.SysretNotRing3;
        }

        if (ss_syscall.get_rpl() != .Ring0) {
            return WriteErrors.SyscallNotRing0;
        }

        write_raw(ss_sysret.selector - 8, cs_syscall.selector);
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
    pub fn read() registers.rflags.RFlags {
        return registers.rflags.RFlags.from_u64(read_msr(register));
    }

    /// Write to the SFMask register.
    /// The SFMASK register is used to specify which RFLAGS bits
    /// are cleared during a SYSCALL. In long mode, SFMASK is used
    /// to specify which RFLAGS bits are cleared when SYSCALL is
    /// executed. If a bit in SFMASK is set to 1, the corresponding
    /// bit in RFLAGS is cleared to 0. If a bit in SFMASK is cleared
    /// to 0, the corresponding rFLAGS bit is not modified.
    pub fn write(value: registers.rflags.RFlags) void {
        write_msr(register, value.to_u64());
    }
};

/// Syscall Register: LSTAR
/// This holds the target RIP of a syscall.
pub const LStar = construct_virtaddr_register(0xC000_0082);

/// FS.Base Model Specific Register.
pub const FsBase = construct_virtaddr_register(0xC000_0100);

/// GS.Base Model Specific Register.
pub const GsBase = construct_virtaddr_register(0xC000_0101);

/// KernelGsBase Model Specific Register.
pub const KernelGsBase = construct_virtaddr_register(0xC000_0102);

fn construct_virtaddr_register(comptime reg: u32) type {
    return struct {
        const register: u32 = reg;

        /// Read the current register value.
        pub fn read() VirtAddr {
            return VirtAddr.init(read_msr(register));
        }

        /// Write a given virtual address to the register.
        pub fn write(addr: VirtAddr) void {
            write_msr(register, addr.value);
        }
    };
}

fn read_msr(reg: u32) u64 {
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

fn write_msr(reg: u32, value: u64) void {
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
    std.meta.refAllDecls(@This());
}
