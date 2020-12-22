usingnamespace @import("../common.zig");

/// Various control flags modifying the basic operation of the CPU.
pub const Cr0 = struct {
    value: u64,

    /// Read the current set of CR0 flags.
    pub fn read() Cr0 {
        return .{ .value = readRaw() & ALL };
    }

    /// Read the current raw CR0 value.
    pub fn readRaw() u64 {
        return asm ("mov %%cr0, %[ret]"
            : [ret] "=r" (-> u64)
        );
    }

    /// Write CR0 flags.
    ///
    /// Preserves the value of reserved fields.
    pub fn write(self: Cr0) void {
        writeRaw(self.value | (readRaw() & NOT_ALL));
    }

    /// Write raw CR0 flags.
    ///
    /// Does _not_ preserve any values, including reserved fields.
    pub fn writeRaw(value: u64) void {
        asm volatile ("mov %[val], %%cr0"
            :
            : [val] "r" (value)
            : "memory"
        );
    }

    pub const ALL: u64 =
        PROTECTED_MODE_ENABLE | MONITOR_COPROCESSOR |
        EMULATE_COPROCESSOR | TASK_SWITCHED |
        NUMERIC_ERROR | WRITE_PROTECT |
        ALIGNMENT_MASK | NOT_WRITE_THROUGH |
        CACHE_DISABLE | PAGING;
    pub const NOT_ALL: u64 = ~ALL;

    /// Enables protected mode.
    pub const PROTECTED_MODE_ENABLE: u64 = 1;
    pub const NOT_PROTECTED_MODE_ENABLE: u64 = ~PROTECTED_MODE_ENABLE;

    /// Enables monitoring of the coprocessor, typical for x87 instructions.
    ///
    /// Controls together with the `TASK_SWITCHED` flag whether a `wait` or `fwait`
    /// instruction should cause a device-not-available exception.
    pub const MONITOR_COPROCESSOR: u64 = 1 << 1;
    pub const NOT_MONITOR_COPROCESSOR: u64 = ~MONITOR_COPROCESSOR;

    /// Force all x87 and MMX instructions to cause an exception.
    pub const EMULATE_COPROCESSOR: u64 = 1 << 2;
    pub const NOT_EMULATE_COPROCESSOR: u64 = ~EMULATE_COPROCESSOR;

    /// Automatically set to 1 on _hardware_ task switch.
    ///
    /// This flags allows lazily saving x87/MMX/SSE instructions on hardware context switches.
    pub const TASK_SWITCHED: u64 = 1 << 3;
    pub const NOT_TASK_SWITCHED: u64 = ~TASK_SWITCHED;

    /// Enables the native error reporting mechanism for x87 FPU errors.
    pub const NUMERIC_ERROR: u64 = 1 << 5;
    pub const NOT_NUMERIC_ERROR: u64 = ~NUMERIC_ERROR;

    /// Controls whether supervisor-level writes to read-only pages are inhibited.
    ///
    /// When set, it is not possible to write to read-only pages from ring 0.
    pub const WRITE_PROTECT: u64 = 1 << 16;
    pub const NOT_WRITE_PROTECT: u64 = ~WRITE_PROTECT;

    /// Enables automatic alignment checking.
    pub const ALIGNMENT_MASK: u64 = 1 << 18;
    pub const NOT_ALIGNMENT_MASK: u64 = ~ALIGNMENT_MASK;

    /// Ignored. Used to control write-back/write-through cache strategy on older CPUs.
    pub const NOT_WRITE_THROUGH: u64 = 1 << 29;
    pub const NOT_NOT_WRITE_THROUGH: u64 = ~NOT_WRITE_THROUGH;

    /// Disables internal caches (only for some cases).
    pub const CACHE_DISABLE: u64 = 1 << 30;
    pub const NOT_CACHE_DISABLE: u64 = ~CACHE_DISABLE;

    /// Enables page translation.
    pub const PAGING: u64 = 1 << 31;
    pub const NOT_PAGING: u64 = ~PAGING;

    test "" {
        std.testing.refAllDecls(@This());
    }
};

/// Contains the Page Fault Linear Address (PFLA).
///
/// When page fault occurs, the CPU sets this register to the accessed address.
pub const Cr2 = struct {
    /// Read the current page fault linear address from the CR2 register.
    pub fn read() VirtAddr {
        // We can use unchecked as this virtual address is set by the CPU itself
        return VirtAddr.initUnchecked(asm ("mov %%cr2, %[ret]"
            : [ret] "=r" (-> u64)
        ));
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

pub const Cr3Flags = struct {
    value: u64,

    pub fn empty() Cr3Flags {
        return .{ .value = 0 };
    }

    pub const ALL: u64 = PAGE_LEVEL_WRITETHROUGH | PAGE_LEVEL_CACHE_DISABLE;
    pub const NOT_ALL: u64 = ~ALL;

    /// Use a writethrough cache policy for the P4 table (else a writeback policy is used).
    pub const PAGE_LEVEL_WRITETHROUGH: u64 = 1 << 3;
    const NOT_PAGE_LEVEL_WRITETHROUGH: u64 = ~PAGE_LEVEL_WRITETHROUGH;

    /// Disable caching for the P4 table.
    pub const PAGE_LEVEL_CACHE_DISABLE: u64 = 1 << 4;
    const NOT_PAGE_LEVEL_CACHE_DISABLE: u64 = ~PAGE_LEVEL_CACHE_DISABLE;

    test "" {
        std.testing.refAllDecls(@This());
    }
};

/// Contains the physical address of the level 4 page table.
pub const Cr3 = struct {
    physFrame: structures.paging.PhysFrame,
    cr3Flags: Cr3Flags,

    /// Read the current P4 table address from the CR3 register.
    pub fn read() Cr3 {
        const value = asm ("mov %%cr3, %[value]"
            : [value] "=r" (-> u64)
        );

        return Cr3{
            .physFrame = structures.paging.PhysFrame.containingAddress(
                // unchecked is fine as the mask ensures validity
                PhysAddr.initUnchecked(value & 0x000f_ffff_ffff_f000),
            ),
            .cr3Flags = .{
                .value = value & Cr3Flags.ALL,
            },
        };
    }

    /// Write a new P4 table address into the CR3 register.
    pub fn write(self: Cr3) void {
        asm volatile ("mov %[value], %%cr3"
            :
            : [value] "r" (self.physFrame.start_address.value | self.cr3Flags.value)
            : "memory"
        );
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

/// Various control flags modifying the basic operation of the CPU while in protected mode.
///
/// Note: The documention for the individual fields is taken from the AMD64 and Intel x86_64 manuals.
pub const Cr4 = struct {
    value: u64,

    /// Read the current set of CR0 flags.
    pub fn read() Cr4 {
        return .{ .value = readRaw() & ALL };
    }

    /// Read the current raw CR4 value.
    pub fn readRaw() u64 {
        return asm ("mov %%cr4, %[ret]"
            : [ret] "=r" (-> u64)
        );
    }

    /// Write CR4 flags.
    ///
    /// Preserves the value of reserved fields.
    pub fn write(self: Cr4) void {
        writeRaw(self.value | (readRaw() & NOT_ALL));
    }

    /// Write raw CR4 flags.
    ///
    /// Does _not_ preserve any values, including reserved fields.
    pub fn writeRaw(value: u64) void {
        asm volatile ("mov %[val], %%cr4"
            :
            : [val] "r" (value)
            : "memory"
        );
    }

    pub const ALL: u64 =
        VIRTUAL_8086_MODE_EXTENSIONS | PROTECTED_MODE_VIRTUAL_INTERRUPTS | TIMESTAMP_DISABLE |
        DEBUGGING_EXTENSIONS | PAGE_SIZE_EXTENSION | PHYSICAL_ADDRESS_EXTENSION |
        MACHINE_CHECK_EXCEPTION | PAGE_GLOBAL | PERFORMANCE_MONITOR_COUNTER |
        OSFXSR | OSXMMEXCPT_ENABLE | USER_MODE_INSTRUCTION_PREVENTION | L5_PAGING |
        VIRTUAL_MACHINE_EXTENSIONS | SAFER_MODE_EXTENSIONS | FSGSBASE |
        PCID | SUPERVISOR_MODE_EXECUTION_PROTECTION | SUPERVISOR_MODE_ACCESS_PREVENTION |
        PROTECTION_KEY;

    pub const NOT_ALL: u64 = ~ALL;

    /// Enables hardware-supported performance enhancements for software running in
    /// virtual-8086 mode.
    pub const VIRTUAL_8086_MODE_EXTENSIONS: u64 = 1;
    pub const NOT_VIRTUAL_8086_MODE_EXTENSIONS: u64 = ~VIRTUAL_8086_MODE_EXTENSIONS;

    /// Enables support for protected-mode virtual interrupts.
    pub const PROTECTED_MODE_VIRTUAL_INTERRUPTS: u64 = 1 << 1;
    pub const NOT_PROTECTED_MODE_VIRTUAL_INTERRUPTS: u64 = ~PROTECTED_MODE_VIRTUAL_INTERRUPTS;

    /// When set, only privilege-level 0 can execute the RDTSC or RDTSCP instructions.
    pub const TIMESTAMP_DISABLE: u64 = 1 << 2;
    pub const NOT_TIMESTAMP_DISABLE: u64 = ~TIMESTAMP_DISABLE;

    /// Enables I/O breakpoint capability and enforces treatment of DR4 and DR5 registers
    /// as reserved.
    pub const DEBUGGING_EXTENSIONS: u64 = 1 << 3;
    pub const NOT_DEBUGGING_EXTENSIONS: u64 = ~DEBUGGING_EXTENSIONS;

    /// Enables the use of 4MB physical frames; ignored in long mode.
    pub const PAGE_SIZE_EXTENSION: u64 = 1 << 4;
    pub const NOT_PAGE_SIZE_EXTENSION: u64 = ~PAGE_SIZE_EXTENSION;

    /// Enables physical address extension and 2MB physical frames; required in long mode.
    pub const PHYSICAL_ADDRESS_EXTENSION: u64 = 1 << 5;
    pub const NOT_PHYSICAL_ADDRESS_EXTENSION: u64 = ~PHYSICAL_ADDRESS_EXTENSION;

    /// Enables the machine-check exception mechanism.
    pub const MACHINE_CHECK_EXCEPTION: u64 = 1 << 6;
    pub const NOT_MACHINE_CHECK_EXCEPTION: u64 = ~MACHINE_CHECK_EXCEPTION;

    /// Enables the global-page mechanism, which allows to make page translations global
    /// to all processes.
    pub const PAGE_GLOBAL: u64 = 1 << 7;
    pub const NOT_PAGE_GLOBAL: u64 = ~PAGE_GLOBAL;

    /// Allows software running at any privilege level to use the RDPMC instruction.
    pub const PERFORMANCE_MONITOR_COUNTER: u64 = 1 << 8;
    pub const NOT_PERFORMANCE_MONITOR_COUNTER: u64 = ~PERFORMANCE_MONITOR_COUNTER;

    /// Enable the use of legacy SSE instructions; allows using FXSAVE/FXRSTOR for saving
    /// processor state of 128-bit media instructions.
    pub const OSFXSR: u64 = 1 << 9;
    pub const NOT_OSFXSR: u64 = ~OSFXSR;

    /// Enables the SIMD floating-point exception (#XF) for handling unmasked 256-bit and
    /// 128-bit media floating-point errors.
    pub const OSXMMEXCPT_ENABLE: u64 = 1 << 10;
    pub const NOT_OSXMMEXCPT_ENABLE: u64 = ~OSXMMEXCPT_ENABLE;

    /// Prevents the execution of the SGDT, SIDT, SLDT, SMSW, and STR instructions by
    /// user-mode software.
    pub const USER_MODE_INSTRUCTION_PREVENTION: u64 = 1 << 11;
    pub const NOT_USER_MODE_INSTRUCTION_PREVENTION: u64 = ~USER_MODE_INSTRUCTION_PREVENTION;

    /// Enables 5-level paging on supported CPUs.
    pub const L5_PAGING: u64 = 1 << 12;
    pub const NOT_L5_PAGING: u64 = ~L5_PAGING;

    /// Enables VMX insturctions.
    pub const VIRTUAL_MACHINE_EXTENSIONS: u64 = 1 << 13;
    pub const NOT_VIRTUAL_MACHINE_EXTENSIONS: u64 = ~VIRTUAL_MACHINE_EXTENSIONS;

    /// Enables SMX instructions.
    pub const SAFER_MODE_EXTENSIONS: u64 = 1 << 14;
    pub const NOT_SAFER_MODE_EXTENSIONS: u64 = ~SAFER_MODE_EXTENSIONS;

    /// Enables software running in 64-bit mode at any privilege level to read and write
    /// the FS.base and GS.base hidden segment register state.
    pub const FSGSBASE: u64 = 1 << 16;
    pub const NOT_FSGSBASE: u64 = ~FSGSBASE;

    /// Enables process-context identifiers (PCIDs).
    pub const PCID: u64 = 1 << 17;
    pub const NOT_PCID: u64 = ~PCID;

    /// Enables extended processor state management instructions, including XGETBV and XSAVE.
    pub const OSXSAVE: u64 = 1 << 18;
    pub const NOT_OSXSAVE: u64 = ~OSXSAVE;

    /// Prevents the execution of instructions that reside in pages accessible by user-mode
    /// software when the processor is in supervisor-mode.
    pub const SUPERVISOR_MODE_EXECUTION_PROTECTION: u64 = 1 << 20;
    pub const NOT_SUPERVISOR_MODE_EXECUTION_PROTECTION: u64 = ~SUPERVISOR_MODE_EXECUTION_PROTECTION;

    /// Enables restrictions for supervisor-mode software when reading data from user-mode
    /// pages.
    pub const SUPERVISOR_MODE_ACCESS_PREVENTION: u64 = 1 << 21;
    pub const NOT_SUPERVISOR_MODE_ACCESS_PREVENTION: u64 = ~SUPERVISOR_MODE_ACCESS_PREVENTION;

    /// Enables 4-level paging to associate each linear address with a protection key.
    pub const PROTECTION_KEY: u64 = 1 << 22;
    pub const NOT_PROTECTION_KEY: u64 = ~PROTECTION_KEY;

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "" {
    std.testing.refAllDecls(@This());
}
