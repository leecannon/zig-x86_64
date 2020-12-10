usingnamespace @import("../common.zig");

/// Various control flags modifying the basic operation of the CPU.
pub const Cr0 = packed struct {
    /// Enables protected mode.
    protected_mode_enable: bool,
    /// Enables monitoring of the coprocessor, typical for x87 instructions.
    ///
    /// Controls together with the `task_switched` flag whether a `wait` or `fwait`
    /// instruction should cause a device-not-available exception.
    monitor_coprocessor: bool,
    /// Force all x87 and MMX instructions to cause an exception
    emulate_coprocessor: bool,
    /// Automatically set to 1 on _hardware_ task switch.
    ///
    /// This flags allows lazily saving x87/MMX/SSE instructions on hardware context switches.
    task_switched: bool,
    _padding4: bool,
    /// Enables the native error reporting mechanism for x87 FPU errors.
    numeric_error: bool,
    _padding6_15: u16,
    /// Controls whether supervisor-level writes to read-only pages are inhibited.
    ///
    /// When set, it is not possible to write to read-only pages from ring 0.
    write_protect: bool,
    _padding17: bool,
    /// Enables automatic alignment checking.
    alignment_mask: bool,
    _padding19_28: u10,
    /// Ignored. Used to control write-back/write-through cache strategy on older CPUs.
    not_write_through: bool,
    /// Disables internal caches (only for some cases).
    cache_disable: bool,
    /// Enables page translation.
    paging: bool,

    // I can't wait for better bitfields in Zig... this is a mess
    _padding_a: u26,

    pub inline fn fromU64(value: u64) Cr0 {
        return @bitCast(Cr0, value & NO_PADDING);
    }

    pub inline fn toU64(self: Cr0) u64 {
        return @bitCast(u64, self) & NO_PADDING;
    }

    const NO_PADDING: u64 = @bitCast(u64, Cr0{
        .protected_mode_enable = true,
        .monitor_coprocessor = true,
        .emulate_coprocessor = true,
        .task_switched = true,
        .numeric_error = true,
        .write_protect = true,
        .alignment_mask = true,
        .not_write_through = true,
        .cache_disable = true,
        .paging = true,
        ._padding4 = false,
        ._padding6_15 = 0,
        ._padding17 = false,
        ._padding19_28 = 0,
        ._padding_a = 0,
    });

    /// Read the current set of CR0 flags.
    pub inline fn read() Cr0 {
        return Cr0.fromU64(readRaw());
    }

    /// Read the current raw CR0 value.
    pub inline fn readRaw() u64 {
        return asm ("mov %%cr0, %[ret]"
            : [ret] "=r" (-> u64)
        );
    }

    /// Write CR0 flags.
    ///
    /// Preserves the value of reserved fields.
    pub fn write(self: Cr0) void {
        const old_value = readRaw();
        const reserved = old_value & ~NO_PADDING;
        const new_value = reserved | self.toU64();
        writeRaw(new_value);
    }

    /// Write raw CR0 flags.
    ///
    /// Does _not_ preserve any values, including reserved fields.
    pub inline fn writeRaw(value: u64) void {
        asm volatile ("mov %[val], %%cr0"
            :
            : [val] "r" (value)
            : "memory"
        );
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "Cr0" {
    std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(Cr0));
    std.testing.expectEqual(@sizeOf(u64), @sizeOf(Cr0));

    const cr0 = Cr0.fromU64(1);
    testing.expectEqual(@as(u64, 1), cr0.toU64());
}

/// Contains the Page Fault Linear Address (PFLA).
///
/// When page fault occurs, the CPU sets this register to the accessed address.
pub const Cr2 = struct {
    /// Read the current page fault linear address from the CR2 register.
    pub inline fn read() VirtAddr {
        return VirtAddr.init(asm ("mov %%cr2, %[ret]"
            : [ret] "=r" (-> u64)
        ));
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

/// Controls cache settings for the level 4 page table.
pub const Cr3 = packed struct {
    _padding0_2: u3,
    /// Use a writethrough cache policy for the P4 table (else a writeback policy is used).
    page_level_writethrough: bool,
    /// Disable caching for the P4 table.
    PAGE_LEVEL_CACHE_DISABLE: bool,

    // I can't wait for better bitfields in Zig... this is a mess
    _padding_a: u3,
    _padding_b: u8,
    _padding_c: u16,
    _padding_d: u32,

    // The padding in this struct is actually required for the struct to be valid.
    // The padding contains the PhysFrame
    pub inline fn fromU64(value: u64) Cr3 {
        return @bitCast(Cr3, value);
    }

    pub inline fn toU64(self: Cr3) u64 {
        return @bitCast(u64, self);
    }

    pub const FrameAndCr3 = struct {
        frame: structures.paging.PhysFrame,
        cr3: Cr3,
    };

    /// Read the current P4 table address from the CR3 register.
    pub fn read() FrameAndCr3 {
        const value = asm ("mov %%cr3, %[value]"
            : [value] "=r" (-> u64)
        );

        const flags = fromU64(value);

        const addr = PhysAddr.init(value & 0x000ffffffffff000);
        const frame = structures.paging.PhysFrame.containingAddress(addr);
        return FrameAndCr3{ .frame = frame, .cr3 = flags };
    }

    /// Write a new P4 table address into the CR3 register.
    pub fn write(data: FrameAndCr3) void {
        const addr = data.frame.start_address;
        const value = addr.value | data.cr3.toU64();

        asm volatile ("mov %[value], %%cr3"
            :
            : [value] "r" (value)
            : "memory"
        );
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "Cr3" {
    std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(Cr3));
    std.testing.expectEqual(@sizeOf(u64), @sizeOf(Cr3));
}

/// Various control flags modifying the basic operation of the CPU while in protected mode.
pub const Cr4 = packed struct {
    /// Enables hardware-supported performance enhancements for software running in
    /// virtual-8086 mode.
    virtual_8086_mode_extensions: bool,
    /// Enables support for protected-mode virtual interrupts.
    protected_mode_virtual_interrupts: bool,
    /// When set, only privilege-level 0 can execute the RDTSC or RDTSCP instructions.
    timestamp_disable: bool,
    /// Enables I/O breakpoint capability and enforces treatment of DR4 and DR5 registers
    /// as reserved.
    debugging_extensions: bool,
    /// Enables the use of 4MB physical frames; ignored in long mode.
    page_size_extension: bool,
    /// Enables physical address extension and 2MB physical frames; required in long mode.
    physical_address_extension: bool,
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
    /// Enables process-context identifiers (PCIDs).
    pcid: bool,
    /// Enables extendet processor state management instructions, including XGETBV and XSAVE.
    osxsave: bool,
    /// Prevents the execution of instructions that reside in pages accessible by user-mode
    /// software when the processor is in supervisor-mode.
    supervisor_mode_execution_protection: bool,
    /// Enables restrictions for supervisor-mode software when reading data from user-mode
    /// pages.
    supervisor_mode_access_prevention: bool,
    /// Enables 4-level paging to associate each linear address with a protection key.
    protection_key: bool,

    // I can't wait for better bitfields in Zig... this is a mess
    _padding_a: u11,
    _padding_b: u32,

    pub inline fn fromU64(value: u64) Cr4 {
        return @bitCast(Cr4, value & NO_PADDING);
    }

    pub inline fn toU64(self: Cr4) u64 {
        return @bitCast(u64, self) & NO_PADDING;
    }

    const NO_PADDING: u64 = @bitCast(u64, Cr4{
        .virtual_8086_mode_extensions = true,
        .protected_mode_virtual_interrupts = true,
        .timestamp_disable = true,
        .debugging_extensions = true,
        .page_size_extension = true,
        .physical_address_extension = true,
        .machine_check_exception = true,
        .page_global = true,
        .performance_monitor_counter = true,
        .osfxsr = true,
        .osxmmexcpt_enable = true,
        .user_mode_instruction_prevention = true,
        .l5_paging = true,
        .virtual_machine_extensions = true,
        .safer_mode_extensions = true,
        .fsgsbase = true,
        .pcid = true,
        .osxsave = true,
        .supervisor_mode_execution_protection = true,
        .supervisor_mode_access_prevention = true,
        .protection_key = true,
        ._padding_a = 0,
        ._padding_b = 0,
    });

    /// Read the current set of Cr4 flags.
    pub inline fn read() Cr4 {
        return Cr4.fromU64(readRaw());
    }

    /// Read the current raw Cr4 value.
    pub inline fn readRaw() u64 {
        return asm ("mov %%cr4, %[ret]"
            : [ret] "=r" (-> u64)
        );
    }

    /// Write Cr4 flags.
    ///
    /// Preserves the value of reserved fields.
    pub fn write(self: Cr4) void {
        const old_value = readRaw();
        const reserved = old_value & ~NO_PADDING;
        const new_value = reserved | self.toU64();
        writeRaw(new_value);
    }

    /// Write raw Cr4 flags.
    ///
    /// Does _not_ preserve any values, including reserved fields.
    pub inline fn writeRaw(value: u64) void {
        asm volatile ("mov %[val], %%cr4"
            :
            : [val] "r" (value)
            : "memory"
        );
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "Cr4" {
    std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(Cr4));
    std.testing.expectEqual(@sizeOf(u64), @sizeOf(Cr4));
}

test "" {
    std.testing.refAllDecls(@This());
}
