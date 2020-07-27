usingnamespace @import("../common.zig");

/// Various control flags modifying the basic operation of the CPU.
pub const Cr0 = packed struct {
    /// Enables protected mode.
    PROTECTED_MODE_ENABLE: bool,
    /// Enables monitoring of the coprocessor, typical for x87 instructions.
    ///
    /// Controls together with the `TASK_SWITCHED` flag whether a `wait` or `fwait`
    /// instruction should cause a device-not-available exception.
    MONITOR_COPROCESSOR: bool,
    /// Force all x87 and MMX instructions to cause an exception
    EMULATE_COPROCESSOR: bool,
    /// Automatically set to 1 on _hardware_ task switch.
    ///
    /// This flags allows lazily saving x87/MMX/SSE instructions on hardware context switches.
    TASK_SWITCHED: bool,
    _padding4: u1,
    /// Enables the native error reporting mechanism for x87 FPU errors.
    NUMERIC_ERROR: bool,
    _padding6_15: u16,
    /// Controls whether supervisor-level writes to read-only pages are inhibited.
    ///
    /// When set, it is not possible to write to read-only pages from ring 0.
    WRITE_PROTECT: bool,
    _padding17: u1,
    /// Enables automatic alignment checking.
    ALIGNMENT_MASK: bool,
    _padding19_28: u10,
    /// Ignored. Used to control write-back/write-through cache strategy on older CPUs.
    NOT_WRITE_THROUGH: bool,
    /// Disables internal caches (only for some cases).
    CACHE_DISABLE: bool,
    /// Enables page translation.
    PAGING: bool,

    // I can't wait for better bitfields in Zig... this is a mess
    _padding_a: u26,

    pub inline fn from_u64(value: u64) Cr0 {
        return @bitCast(Cr0, value);
    }

    pub inline fn to_u64(self: Cr0) u64 {
        return @bitCast(u64, self);
    }

    /// Read the current raw CR0 value.
    pub inline fn read_raw() Cr0 {
        const raw = asm ("mov %%cr0, %[ret]"
            : [ret] "=r" (-> u64)
        );
        return from_u64(raw);
    }

    /// Write raw CR0 flags.
    ///
    /// Does _not_ preserve any values, including reserved fields.
    pub inline fn write_raw(self: Cr0) void {
        asm volatile ("mov %[val], %%cr0"
            :
            : [val] "r" (self.to_u64())
            : "memory"
        );
    }
};

test "Cr0" {
    std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(Cr0));
    std.testing.expectEqual(@sizeOf(u64), @sizeOf(Cr0));
}

/// Contains the Page Fault Linear Address (PFLA).
///
/// When page fault occurs, the CPU sets this register to the accessed address.
pub const Cr2 = struct {
    /// Read the current page fault linear address from the CR2 register.
    pub inline fn read() VirtAddr {
        const value = asm ("mov %%cr2, %[ret]"
            : [ret] "=r" (-> u64)
        );
        return VirtAddr.new(value);
    }
};

/// Controls cache settings for the level 4 page table.
pub const Cr3 = packed struct {
    _padding0_2: u3,
    /// Use a writethrough cache policy for the P4 table (else a writeback policy is used).
    PAGE_LEVEL_WRITETHROUGH: bool,
    /// Disable caching for the P4 table.
    PAGE_LEVEL_CACHE_DISABLE: bool,

    // I can't wait for better bitfields in Zig... this is a mess
    _padding_a: u3,
    _padding_b: u8,
    _padding_c: u16,
    _padding_d: u32,

    pub inline fn from_u64(value: u64) Cr3 {
        return @bitCast(Cr3, value);
    }

    pub inline fn to_u64(self: Cr3) u64 {
        return @bitCast(u64, self);
    }

    // TODO: Waiting on PhysFrame
    // pub const FrameAndCr3 = struct {
    //     frame: PhysFrame,
    //     cr3: Cr3,
    // };

    // TODO: Waiting on PhysFrame
    // /// Read the current P4 table address from the CR3 register.
    // pub inline fn read() FrameAndCr3 {
    //
    // }

    // TODO: Waiting on PhysFrame
    // /// Write a new P4 table address into the CR3 register.
    // pub inline fn write(data: FrameAndCr3) void {
    //
    // }
};

test "Cr3" {
    std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(Cr3));
    std.testing.expectEqual(@sizeOf(u64), @sizeOf(Cr3));
}

/// Various control flags modifying the basic operation of the CPU while in protected mode.
pub const Cr4 = packed struct {
    /// Enables hardware-supported performance enhancements for software running in
    /// virtual-8086 mode.
    VIRTUAL_8086_MODE_EXTENSIONS: bool,
    /// Enables support for protected-mode virtual interrupts.
    PROTECTED_MODE_VIRTUAL_INTERRUPTS: bool,
    /// When set, only privilege-level 0 can execute the RDTSC or RDTSCP instructions.
    TIMESTAMP_DISABLE: bool,
    /// Enables I/O breakpoint capability and enforces treatment of DR4 and DR5 registers
    /// as reserved.
    DEBUGGING_EXTENSIONS: bool,
    /// Enables the use of 4MB physical frames; ignored in long mode.
    PAGE_SIZE_EXTENSION: bool,
    /// Enables physical address extension and 2MB physical frames; required in long mode.
    PHYSICAL_ADDRESS_EXTENSION: bool,
    /// Enables the machine-check exception mechanism.
    MACHINE_CHECK_EXCEPTION: bool,
    /// Enables the global-page mechanism, which allows to make page translations global
    /// to all processes.
    PAGE_GLOBAL: bool,
    /// Allows software running at any privilege level to use the RDPMC instruction.
    PERFORMANCE_MONITOR_COUNTER: bool,
    /// Enable the use of legacy SSE instructions; allows using FXSAVE/FXRSTOR for saving
    /// processor state of 128-bit media instructions.
    OSFXSR: bool,
    /// Enables the SIMD floating-point exception (#XF) for handling unmasked 256-bit and
    /// 128-bit media floating-point errors.
    OSXMMEXCPT_ENABLE: bool,
    /// Prevents the execution of the SGDT, SIDT, SLDT, SMSW, and STR instructions by
    /// user-mode software.
    USER_MODE_INSTRUCTION_PREVENTION: bool,
    /// Enables 5-level paging on supported CPUs.
    L5_PAGING: bool,
    /// Enables VMX insturctions.
    VIRTUAL_MACHINE_EXTENSIONS: bool,
    /// Enables SMX instructions.
    SAFER_MODE_EXTENSIONS: bool,
    /// Enables software running in 64-bit mode at any privilege level to read and write
    /// the FS.base and GS.base hidden segment register state.
    FSGSBASE: bool,
    /// Enables process-context identifiers (PCIDs).
    PCID: bool,
    /// Enables extendet processor state management instructions, including XGETBV and XSAVE.
    OSXSAVE: bool,
    /// Prevents the execution of instructions that reside in pages accessible by user-mode
    /// software when the processor is in supervisor-mode.
    SUPERVISOR_MODE_EXECUTION_PROTECTION: bool,
    /// Enables restrictions for supervisor-mode software when reading data from user-mode
    /// pages.
    SUPERVISOR_MODE_ACCESS_PREVENTION: bool,
    /// Enables 4-level paging to associate each linear address with a protection key.
    PROTECTION_KEY: bool,

    // I can't wait for better bitfields in Zig... this is a mess
    _padding_a: u11,
    _padding_b: u32,

    pub inline fn from_u64(value: u64) Cr4 {
        return @bitCast(Cr4, value);
    }

    pub inline fn to_u64(self: Cr4) u64 {
        return @bitCast(u64, self);
    }

    /// Read the current raw CR4 value.
    pub inline fn read_raw() Cr4 {
        const raw = asm ("mov %%cr4, %[ret]"
            : [ret] "=r" (-> u64)
        );
        return from_u64(raw);
    }

    /// Write raw CR4 flags.
    ///
    /// Does _not_ preserve any values, including reserved fields.
    pub inline fn write_raw(self: Cr4) void {
        asm volatile ("mov %[val], %%cr4"
            :
            : [val] "r" (self.to_u64())
            : "memory"
        );
    }
};

test "Cr4" {
    std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(Cr4));
    std.testing.expectEqual(@sizeOf(u64), @sizeOf(Cr4));
}
