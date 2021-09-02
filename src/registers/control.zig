usingnamespace @import("../common.zig");

/// Various control flags modifying the basic operation of the CPU.
pub const Cr0 = packed struct {
    /// Enables protected mode.
    protected: bool,

    /// Enables monitoring of the coprocessor, typical for x87 instructions.
    ///
    /// Controls together with the `TASK_SWITCHED` flag whether a `wait` or `fwait`
    /// instruction should cause a device-not-available exception.
    monitor_coprocessor: bool,

    /// Force all x87 and MMX instructions to cause an exception.
    emulate_coprocessor: bool,

    /// Automatically set to 1 on _hardware_ task switch.
    ///
    /// This flags allows lazily saving x87/MMX/SSE instructions on hardware context switches.
    task_switched: bool,

    extension_type: bool,
    numeric_error: bool,

    z_reserved6_15: u10,

    /// Controls whether supervisor-level writes to read-only pages are inhibited.
    ///
    /// When set, it is not possible to write to read-only pages from ring 0.
    write_protect: bool,

    z_reserved17: bool,

    /// Enables automatic alignment checking.
    alignment_check: bool,

    z_reserved19_28: u10,

    /// Ignored. Used to control write-back/write-through cache strategy on older CPUs.
    not_write_through: bool,

    /// Disables internal caches (only for some cases).
    cache_disabled: bool,

    /// Enables page translation.
    paging: bool,

    z_reserved32_63: u32,

    /// Read the current set of CR0 flags.
    pub fn read() Cr0 {
        return Cr0.fromU64(readRaw());
    }

    /// Read the current raw CR0 value.
    fn readRaw() u64 {
        return asm ("mov %%cr0, %[ret]"
            : [ret] "=r" (-> u64),
        );
    }

    /// Write CR0 flags.
    ///
    /// Preserves the value of reserved fields.
    pub fn write(self: Cr0) void {
        writeRaw(self.toU64() | (readRaw() & ALL_RESERVED));
    }

    /// Write raw CR0 flags.
    ///
    /// Does _not_ preserve any values, including reserved fields.
    fn writeRaw(value: u64) void {
        asm volatile ("mov %[val], %%cr0"
            :
            : [val] "r" (value),
            : "memory"
        );
    }

    const ALL_RESERVED: u64 = blk: {
        var flags = std.mem.zeroes(Cr0);
        flags.z_reserved6_15 = std.math.maxInt(u10);
        flags.z_reserved17 = true;
        flags.z_reserved19_28 = std.math.maxInt(u10);
        flags.z_reserved32_63 = std.math.maxInt(u32);
        break :blk @bitCast(u64, flags);
    };

    const ALL_NOT_RESERVED: u64 = ~ALL_RESERVED;

    pub fn fromU64(value: u64) Cr0 {
        return @bitCast(Cr0, value & ALL_NOT_RESERVED);
    }

    pub fn toU64(self: Cr0) u64 {
        return @bitCast(u64, self) & ALL_NOT_RESERVED;
    }

    pub fn format(value: Cr0, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        return formatWithoutFields(
            value,
            options,
            writer,
            &.{"z_reserved"},
        );
    }

    test {
        try std.testing.expectEqual(@as(usize, 64), @bitSizeOf(Cr0));
        try std.testing.expectEqual(@as(usize, 8), @sizeOf(Cr0));
        try std.testing.expectEqual(@as(usize, 0b11100000000001010000000000111111), ALL_NOT_RESERVED);
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Contains the Page Fault Linear Address (PFLA).
///
/// When page fault occurs, the CPU sets this register to the accessed address.
pub const Cr2 = struct {
    /// Read the current page fault linear address from the CR2 register.
    pub fn read() x86_64.VirtAddr {
        // We can use unchecked as this virtual address is set by the CPU itself
        return x86_64.VirtAddr.initUnchecked(asm ("mov %%cr2, %[ret]"
            : [ret] "=r" (-> u64),
        ));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const Cr3Flags = packed struct {
    z_reserved0: bool,
    z_reserved1: bool,

    /// Use a writethrough cache policy for the P4 table (else a writeback policy is used).
    page_level_writethrough: bool,

    /// Disable caching for the P4 table.
    page_level_cache_disable: bool,

    z_reserved4_63: u60,

    const ALL_RESERVED: u64 = blk: {
        var flags = std.mem.zeroes(Cr3Flags);
        flags.z_reserved0 = true;
        flags.z_reserved1 = true;
        flags.z_reserved4_63 = std.math.maxInt(u60);
        break :blk @bitCast(u64, flags);
    };

    const ALL_NOT_RESERVED: u64 = ~ALL_RESERVED;

    pub fn fromU64(value: u64) Cr3Flags {
        return @bitCast(Cr3Flags, value & ALL_NOT_RESERVED);
    }

    pub fn toU64(self: Cr3Flags) u64 {
        return @bitCast(u64, self) & ALL_NOT_RESERVED;
    }

    pub fn format(value: Cr3Flags, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        return formatWithoutFields(
            value,
            options,
            writer,
            &.{"z_reserved"},
        );
    }

    test {
        try std.testing.expectEqual(@as(usize, 64), @bitSizeOf(Cr3Flags));
        try std.testing.expectEqual(@as(usize, 8), @sizeOf(Cr3Flags));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Contains the physical address of the level 4 page table.
pub const Cr3 = struct {
    pub const Contents = struct {
        phys_frame: x86_64.structures.paging.PhysFrame,
        cr3_flags: Cr3Flags,

        pub fn toU64(self: Contents) u64 {
            return self.phys_frame.start_address.value | self.cr3_flags.toU64();
        }
    };

    pub const PcidContents = struct {
        phys_frame: x86_64.structures.paging.PhysFrame,
        pcid: x86_64.instructions.tlb.Pcid,

        pub fn toU64(self: PcidContents) u64 {
            return self.phys_frame.start_address.value | @as(u64, self.pcid.value);
        }
    };

    /// Read the current P4 table address from the CR3 register.
    pub fn read() Contents {
        const value = readRaw();

        return .{
            .phys_frame = x86_64.structures.paging.PhysFrame.containingAddress(
                // unchecked is fine as the mask ensures validity
                x86_64.PhysAddr.initUnchecked(value & 0x000f_ffff_ffff_f000),
            ),
            .cr3_flags = Cr3Flags.fromU64(value),
        };
    }

    /// Read the raw value from the CR3 register
    fn readRaw() u64 {
        return asm ("mov %%cr3, %[value]"
            : [value] "=r" (-> u64),
        );
    }

    /// Read the current P4 table address from the CR3 register along with PCID.
    /// The correct functioning of this requires CR4.PCIDE = 1.
    /// See [`Cr4Flags::PCID`]
    pub fn readPcid() PcidContents {
        const value = readRaw();

        return .{
            .phys_frame = x86_64.structures.paging.PhysFrame.containingAddress(
                // unchecked is fine as the mask ensures validity
                x86_64.PhysAddr.initUnchecked(value & 0x000f_ffff_ffff_f000),
            ),
            .pcid = x86_64.instructions.tlb.Pcid.init(@truncate(u12, value & 0xFFF)),
        };
    }

    /// Write a new P4 table address into the CR3 register.
    pub fn write(contents: Contents) void {
        writeRaw(contents.toU64());
    }

    /// Write a new P4 table address into the CR3 register.
    ///
    /// ## Safety
    /// Changing the level 4 page table is unsafe, because it's possible to violate memory safety by
    /// changing the page mapping.
    /// [`Cr4Flags::PCID`] must be set before calling this method.
    pub fn writePcid(pcidContents: PcidContents) void {
        writeRaw(pcidContents.toU64());
    }

    fn writeRaw(value: u64) void {
        asm volatile ("mov %[value], %%cr3"
            :
            : [value] "r" (value),
            : "memory"
        );
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Various control flags modifying the basic operation of the CPU while in protected mode.
///
/// Note: The documention for the individual fields is taken from the AMD64 and Intel x86_64 manuals.
pub const Cr4 = packed struct {
    /// Enables hardware-supported performance enhancements for software running in
    /// virtual-8086 mode.
    virtual_8086_mode_extensions: bool,

    /// Enables support for protected-mode virtual interrupts.
    protected_mode_virtual_interrupts: bool,

    /// When set, only privilege-level 0 can execute the RDTSC or RDTSCP instructions.
    timestamp_disable: bool,

    /// Enables I/O breakpoint capability and enforces treatment of DR4 and DR5 x86_64 registers
    /// as reserved.
    debugging_extensions: bool,

    /// Enables the use of 4MB physical frames; ignored in long mode.
    page_size_extension: bool,

    /// Enables physical address extension and 2MB physical frames; required in long mode.
    physical_address_translation: bool,

    /// Enables the machine-check exception mechanism.
    machine_check_exception: bool,

    /// Enables the global-page mechanism, which allows to make page translations global
    /// to all processes.
    page_global: bool,

    /// Allows software running at any privilege level to use the RDPMC instruction.
    performance_monitor_counter: bool,

    /// Enable the use of legacy SSE instructions; allows using FXSAVE/FXRSTOR for saving
    /// processor state of 128-bit media instructions.
    osfxsr: bool,

    /// Enables the SIMD floating-point exception (#XF) for handling unmasked 256-bit and
    /// 128-bit media floating-point errors.
    osxmmexcpt_enable: bool,

    /// Prevents the execution of the SGDT, SIDT, SLDT, SMSW, and STR instructions by
    /// user-mode software.
    user_mode_instruction_prevention: bool,

    /// Enables 5-level paging on supported CPUs.
    l5_paging: bool,

    /// Enables VMX insturctions.
    virtual_machine_extensions: bool,

    /// Enables SMX instructions.
    safer_mode_extensions: bool,

    /// Enables software running in 64-bit mode at any privilege level to read and write
    /// the FS.base and GS.base hidden segment register state.
    fsgsbase: bool,

    z_reserved16: bool,

    /// Enables process-context identifiers (PCIDs).
    pcid: bool,

    /// Enables extended processor state management instructions, including XGETBV and XSAVE.
    osxsave: bool,

    z_reserved19: bool,

    /// Prevents the execution of instructions that reside in pages accessible by user-mode
    /// software when the processor is in supervisor-mode.
    supervisor_mode_execution_prevention: bool,

    /// Enables restrictions for supervisor-mode software when reading data from user-mode
    /// pages.
    supervisor_mode_access_prevention: bool,

    /// Enables 4-level paging to associate each linear address with a protection key.
    protection_key: bool,

    z_reserved23_31: u9,
    z_reserved32_63: u32,

    /// Read the current set of CR0 flags.
    pub fn read() Cr4 {
        return Cr4.fromU64(readRaw());
    }

    /// Read the current raw CR4 value.
    fn readRaw() u64 {
        return asm ("mov %%cr4, %[ret]"
            : [ret] "=r" (-> u64),
        );
    }

    /// Write CR4 flags.
    ///
    /// Preserves the value of reserved fields.
    pub fn write(self: Cr4) void {
        writeRaw(self.toU64() | (readRaw() & ALL_RESERVED));
    }

    /// Write raw CR4 flags.
    ///
    /// Does _not_ preserve any values, including reserved fields.
    fn writeRaw(value: u64) void {
        asm volatile ("mov %[val], %%cr4"
            :
            : [val] "r" (value),
            : "memory"
        );
    }

    const ALL_RESERVED: u64 = blk: {
        var flags = std.mem.zeroes(Cr4);
        flags.z_reserved16 = true;
        flags.z_reserved19 = true;
        flags.z_reserved23_31 = std.math.maxInt(u9);
        flags.z_reserved32_63 = std.math.maxInt(u32);
        break :blk @bitCast(u64, flags);
    };

    const ALL_NOT_RESERVED: u64 = ~ALL_RESERVED;

    pub fn fromU64(value: u64) Cr4 {
        return @bitCast(Cr4, value & ALL_NOT_RESERVED);
    }

    pub fn toU64(self: Cr4) u64 {
        return @bitCast(u64, self) & ALL_NOT_RESERVED;
    }

    pub fn format(value: Cr4, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        return formatWithoutFields(
            value,
            options,
            writer,
            &.{"z_reserved"},
        );
    }

    test {
        try std.testing.expectEqual(@as(usize, 64), @bitSizeOf(Cr4));
        try std.testing.expectEqual(@as(usize, 8), @sizeOf(Cr4));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
