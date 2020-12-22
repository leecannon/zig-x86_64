usingnamespace @import("../common.zig");

/// The Extended Feature Enable Register.
pub const Efer = struct {
    value: u64,

    const REGISTER = Msr(0xC000_0080);

    /// Read the current EFER flags.
    pub fn read() Efer {
        return .{ .value = readRaw() & ALL };
    }

    /// Read the current raw CR0 value.
    pub fn readRaw() u64 {
        return REGISTER.read();
    }

    /// Write the EFER flags, preserving reserved values.
    ///
    /// Preserves the value of reserved fields.
    pub fn write(self: Efer) void {
        writeRaw(self.value | (readRaw() & NOT_ALL));
    }

    /// Write the EFER flags.
    ///
    /// Does not preserve any bits, including reserved fields.
    pub fn writeRaw(value: u64) void {
        REGISTER.write(value);
    }

    pub const ALL: u64 =
        SYSTEM_CALL_EXTENSIONS | LONG_MODE_ENABLE | LONG_MODE_ACTIVE | NO_EXECUTE_ENABLE |
        SECURE_VIRTUAL_MACHINE_ENABLE | LONG_MODE_SEGMENT_LIMIT_ENABLE | FAST_FXSAVE_FXRSTOR |
        TRANSLATION_CACHE_EXTENSION;

    pub const NOT_ALL: u64 = ~ALL;

    /// Enables the `syscall` and `sysret` instructions.
    pub const SYSTEM_CALL_EXTENSIONS: u64 = 1;
    pub const NOT_SYSTEM_CALL_EXTENSIONS: u64 = ~SYSTEM_CALL_EXTENSIONS;

    /// Activates long mode, requires activating paging.
    pub const LONG_MODE_ENABLE: u64 = 1 << 8;
    pub const NOT_LONG_MODE_ENABLE: u64 = ~LONG_MODE_ENABLE;

    /// Indicates that long mode is active.
    pub const LONG_MODE_ACTIVE: u64 = 1 << 10;
    pub const NOT_LONG_MODE_ACTIVE: u64 = ~LONG_MODE_ACTIVE;

    /// Enables the no-execute page-protection feature.
    pub const NO_EXECUTE_ENABLE: u64 = 1 << 11;
    pub const NOT_NO_EXECUTE_ENABLE: u64 = ~NO_EXECUTE_ENABLE;

    /// Enables SVM extensions.
    pub const SECURE_VIRTUAL_MACHINE_ENABLE: u64 = 1 << 12;
    pub const NOT_SECURE_VIRTUAL_MACHINE_ENABLE: u64 = ~SECURE_VIRTUAL_MACHINE_ENABLE;

    /// Enable certain limit checks in 64-bit mode.
    pub const LONG_MODE_SEGMENT_LIMIT_ENABLE: u64 = 1 << 13;
    pub const NOT_LONG_MODE_SEGMENT_LIMIT_ENABLE: u64 = ~LONG_MODE_SEGMENT_LIMIT_ENABLE;

    /// Enable the `fxsave` and `fxrstor` instructions to execute faster in 64-bit mode.
    pub const FAST_FXSAVE_FXRSTOR: u64 = 1 << 14;
    pub const NOT_FAST_FXSAVE_FXRSTOR: u64 = ~FAST_FXSAVE_FXRSTOR;

    /// Changes how the `invlpg` instruction operates on TLB entries of upper-level entries.
    pub const TRANSLATION_CACHE_EXTENSION: u64 = 1 << 15;
    pub const NOT_TRANSLATION_CACHE_EXTENSION: u64 = ~TRANSLATION_CACHE_EXTENSION;

    test "" {
        std.testing.refAllDecls(@This());
    }
};

/// FS.Base Model Specific Register.
pub const FsBase = struct {
    const REGISTER = Msr(0xC000_0100);

    /// Read the current FsBase register.
    pub fn read() VirtAddr {
        // We use unchecked here as we assume that the write function did not write an invalid address
        return VirtAddr.initUnchecked(REGISTER.read());
    }

    /// Write a given virtual address to the FS.Base register.
    pub fn write(addr: VirtAddr) void {
        REGISTER.write(addr.value);
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

/// GS.Base Model Specific Register.
pub const GsBase = struct {
    const REGISTER = Msr(0xC000_0101);

    /// Read the current GsBase register.
    pub fn read() VirtAddr {
        // We use unchecked here as we assume that the write function did not write an invalid address
        return VirtAddr.initUnchecked(REGISTER.read());
    }

    /// Write a given virtual address to the GS.Base register.
    pub fn write(addr: VirtAddr) void {
        REGISTER.write(addr.value);
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

/// KernelGsBase Model Specific Register.
pub const KernelGsBase = struct {
    const REGISTER = Msr(0xC000_0102);

    /// Read the current KernelGsBase register.
    pub fn read() VirtAddr {
        // We use unchecked here as we assume that the write function did not write an invalid address
        return VirtAddr.initUnchecked(REGISTER.read());
    }

    /// Write a given virtual address to the KernelGsBase register.
    pub fn write(addr: VirtAddr) void {
        REGISTER.write(addr.value);
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

/// Syscall Register: STAR
pub const Star = struct {
    sysretCsSelector: structures.gdt.SegmentSelector,
    sysretSsSelector: structures.gdt.SegmentSelector,
    syscallCsSelector: structures.gdt.SegmentSelector,
    syscallSsSelector: structures.gdt.SegmentSelector,

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
            @truncate(u16, getBits(val, 48, 64)),
            @truncate(u16, getBits(val, 32, 48)),
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
        if ((self.sysretSsSelector.getRpl() catch return WriteError.SysretNotRing3) != .Ring3) {
            return WriteError.SysretNotRing3;
        }
        if ((self.syscallSsSelector.getRpl() catch return WriteError.SyscallNotRing0) != .Ring0) {
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
        setBits(&value, 48, 64, sysret);
        setBits(&value, 32, 48, syscall);
        REGISTER.write(value);
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

/// Syscall Register: LSTAR
pub const LStar = struct {
    const REGISTER = Msr(0xC000_0082);

    /// Read the current LStar register.
    /// This holds the target RIP of a syscall.
    pub fn read() VirtAddr {
        // We use unchecked here as we assume that the write function did not write an invalid address
        return VirtAddr.initUnchecked(REGISTER.read());
    }

    /// Write a given virtual address to the LStar register.
    /// This holds the target RIP of a syscall.
    pub fn write(addr: VirtAddr) void {
        REGISTER.write(addr.value);
    }

    test "" {
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
    pub fn read() registers.RFlags {
        return .{ .value = REGISTER.read() & registers.RFlags.ALL };
    }

    /// Write to the SFMask register.
    /// The SFMASK register is used to specify which RFLAGS bits
    /// are cleared during a SYSCALL. In long mode, SFMASK is used
    /// to specify which RFLAGS bits are cleared when SYSCALL is
    /// executed. If a bit in SFMASK is set to 1, the corresponding
    /// bit in RFLAGS is cleared to 0. If a bit in SFMASK is cleared
    /// to 0, the corresponding rFLAGS bit is not modified.
    pub fn write(value: registers.RFlags) void {
        REGISTER.write(value.value & registers.RFlags.ALL);
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

fn Msr(comptime register: u32) type {
    return struct {
        pub fn read() u64 {
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

        pub fn write(value: u64) void {
            asm volatile ("wrmsr"
                :
                : [reg] "{ecx}" (register),
                  [low] "{eax}" (@truncate(u32, value)),
                  [high] "{edx}" (@truncate(u32, value >> 32))
                : "memory"
            );
        }

        test "" {
            std.testing.refAllDecls(@This());
        }
    };
}

test "" {
    std.testing.refAllDecls(@This());
}
