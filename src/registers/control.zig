usingnamespace @import("../common.zig");

/// Various control flags modifying the basic operation of the CPU.
pub const Cr0 = struct {
    value: u64,

    /// Read the current set of CR0 flags.
    pub fn read() Cr0 {
        return .{ .value = readRaw() & ALL };
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
        writeRaw(self.value | (readRaw() & NOT_ALL));
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
    pub inline fn isPROTECTED_MODE_ENABLE(self: Cr0) bool {
        return self.value & PROTECTED_MODE_ENABLE != 0;
    }

    /// Enables monitoring of the coprocessor, typical for x87 instructions.
    ///
    /// Controls together with the `TASK_SWITCHED` flag whether a `wait` or `fwait`
    /// instruction should cause a device-not-available exception.
    pub const MONITOR_COPROCESSOR: u64 = 1 << 1;
    pub const NOT_MONITOR_COPROCESSOR: u64 = ~MONITOR_COPROCESSOR;
    pub inline fn isMONITOR_COPROCESSOR(self: Cr0) bool {
        return self.value & MONITOR_COPROCESSOR != 0;
    }

    /// Force all x87 and MMX instructions to cause an exception.
    pub const EMULATE_COPROCESSOR: u64 = 1 << 2;
    pub const NOT_EMULATE_COPROCESSOR: u64 = ~EMULATE_COPROCESSOR;
    pub inline fn isEMULATE_COPROCESSOR(self: Cr0) bool {
        return self.value & EMULATE_COPROCESSOR != 0;
    }

    /// Automatically set to 1 on _hardware_ task switch.
    ///
    /// This flags allows lazily saving x87/MMX/SSE instructions on hardware context switches.
    pub const TASK_SWITCHED: u64 = 1 << 3;
    pub const NOT_TASK_SWITCHED: u64 = ~TASK_SWITCHED;
    pub inline fn isTASK_SWITCHED(self: Cr0) bool {
        return self.value & TASK_SWITCHED != 0;
    }

    /// Enables the native error reporting mechanism for x87 FPU errors.
    pub const NUMERIC_ERROR: u64 = 1 << 5;
    pub const NOT_NUMERIC_ERROR: u64 = ~NUMERIC_ERROR;
    pub inline fn isNUMERIC_ERROR(self: Cr0) bool {
        return self.value & NUMERIC_ERROR != 0;
    }

    /// Controls whether supervisor-level writes to read-only pages are inhibited.
    ///
    /// When set, it is not possible to write to read-only pages from ring 0.
    pub const WRITE_PROTECT: u64 = 1 << 16;
    pub const NOT_WRITE_PROTECT: u64 = ~WRITE_PROTECT;
    pub inline fn isWRITE_PROTECT(self: Cr0) bool {
        return self.value & WRITE_PROTECT != 0;
    }

    /// Enables automatic alignment checking.
    pub const ALIGNMENT_MASK: u64 = 1 << 18;
    pub const NOT_ALIGNMENT_MASK: u64 = ~ALIGNMENT_MASK;
    pub inline fn isALIGNMENT_MASK(self: Cr0) bool {
        return self.value & ALIGNMENT_MASK != 0;
    }

    /// Ignored. Used to control write-back/write-through cache strategy on older CPUs.
    pub const NOT_WRITE_THROUGH: u64 = 1 << 29;
    pub const NOT_NOT_WRITE_THROUGH: u64 = ~NOT_WRITE_THROUGH;
    pub inline fn isNOT_WRITE_THROUGH(self: Cr0) bool {
        return self.value & NOT_WRITE_THROUGH != 0;
    }

    /// Disables internal caches (only for some cases).
    pub const CACHE_DISABLE: u64 = 1 << 30;
    pub const NOT_CACHE_DISABLE: u64 = ~CACHE_DISABLE;
    pub inline fn isCACHE_DISABLE(self: Cr0) bool {
        return self.value & CACHE_DISABLE != 0;
    }

    /// Enables page translation.
    pub const PAGING: u64 = 1 << 31;
    pub const NOT_PAGING: u64 = ~PAGING;
    pub inline fn isPAGING(self: Cr0) bool {
        return self.value & PAGING != 0;
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
    pub inline fn read() x86_64.VirtAddr {
        // We can use unchecked as this virtual address is set by the CPU itself
        return x86_64.VirtAddr.initUnchecked(asm ("mov %%cr2, %[ret]"
            : [ret] "=r" (-> u64)
        ));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const Cr3Flags = struct {
    value: u64,

    pub inline fn empty() Cr3Flags {
        return .{ .value = 0 };
    }

    pub const ALL: u64 = PAGE_LEVEL_WRITETHROUGH | PAGE_LEVEL_CACHE_DISABLE;
    pub const NOT_ALL: u64 = ~ALL;

    /// Use a writethrough cache policy for the P4 table (else a writeback policy is used).
    pub const PAGE_LEVEL_WRITETHROUGH: u64 = 1 << 3;
    const NOT_PAGE_LEVEL_WRITETHROUGH: u64 = ~PAGE_LEVEL_WRITETHROUGH;
    pub inline fn isPAGE_LEVEL_WRITETHROUGH(self: Cr3Flags) bool {
        return self.value & PAGE_LEVEL_WRITETHROUGH != 0;
    }

    /// Disable caching for the P4 table.
    pub const PAGE_LEVEL_CACHE_DISABLE: u64 = 1 << 4;
    const NOT_PAGE_LEVEL_CACHE_DISABLE: u64 = ~PAGE_LEVEL_CACHE_DISABLE;
    pub inline fn isPAGE_LEVEL_CACHE_DISABLE(self: Cr3Flags) bool {
        return self.value & PAGE_LEVEL_CACHE_DISABLE != 0;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Contains the physical address of the level 4 page table.
pub const Cr3 = struct {
    pub const Contents = struct {
        physFrame: x86_64.structures.paging.PhysFrame,
        cr3Flags: Cr3Flags,
    };

    pub const PcidContents = struct {
        physFrame: x86_64.structures.paging.PhysFrame,
        pcid: x86_64.instructions.tlb.Pcid,
    };

    /// Read the current P4 table address from the CR3 register.
    pub fn read() Contents {
        const value = readRaw();

        return .{
            .physFrame = x86_64.structures.paging.PhysFrame.containingAddress(
                // unchecked is fine as the mask ensures validity
                x86_64.PhysAddr.initUnchecked(value & 0x000f_ffff_ffff_f000),
            ),
            .cr3Flags = .{
                .value = value & Cr3Flags.ALL,
            },
        };
    }

    /// Read the raw value from the CR3 register
    pub inline fn readRaw() u64 {
        return asm ("mov %%cr3, %[value]"
            : [value] "=r" (-> u64)
        );
    }

    /// Read the current P4 table address from the CR3 register along with PCID.
    /// The correct functioning of this requires CR4.PCIDE = 1.
    /// See [`Cr4Flags::PCID`]
    pub fn readPcid() PcidContents {
        const value = readRaw();

        return .{
            .physFrame = x86_64.structures.paging.PhysFrame.containingAddress(
                // unchecked is fine as the mask ensures validity
                x86_64.PhysAddr.initUnchecked(value & 0x000f_ffff_ffff_f000),
            ),
            .pcid = x86_64.instructions.tlb.Pcid.init(@truncate(u12, value & 0xFFF)),
        };
    }

    /// Write a new P4 table address into the CR3 register.
    pub fn write(contents: Contents) void {
        writeRaw(contents.physFrame.start_address.value | contents.cr3Flags.value);
    }

    /// Write a new P4 table address into the CR3 register.
    ///
    /// ## Safety
    /// Changing the level 4 page table is unsafe, because it's possible to violate memory safety by
    /// changing the page mapping.
    /// [`Cr4Flags::PCID`] must be set before calling this method.
    pub fn writePcid(pcidContents: PcidContents) void {
        writeRaw(pcidContents.physFrame.start_address.value | @as(u64, pcidContents.pcid.value));
    }

    pub inline fn writeRaw(value: u64) void {
        asm volatile ("mov %[value], %%cr3"
            :
            : [value] "r" (value)
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
pub const Cr4 = struct {
    value: u64,

    /// Read the current set of CR0 flags.
    pub fn read() Cr4 {
        return .{ .value = readRaw() & ALL };
    }

    /// Read the current raw CR4 value.
    pub inline fn readRaw() u64 {
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
    pub inline fn writeRaw(value: u64) void {
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
    pub inline fn isVIRTUAL_8086_MODE_EXTENSIONS(self: Cr4) bool {
        return self.value & VIRTUAL_8086_MODE_EXTENSIONS != 0;
    }

    /// Enables support for protected-mode virtual interrupts.
    pub const PROTECTED_MODE_VIRTUAL_INTERRUPTS: u64 = 1 << 1;
    pub const NOT_PROTECTED_MODE_VIRTUAL_INTERRUPTS: u64 = ~PROTECTED_MODE_VIRTUAL_INTERRUPTS;
    pub inline fn isPROTECTED_MODE_VIRTUAL_INTERRUPTS(self: Cr4) bool {
        return self.value & PROTECTED_MODE_VIRTUAL_INTERRUPTS != 0;
    }

    /// When set, only privilege-level 0 can execute the RDTSC or RDTSCP instructions.
    pub const TIMESTAMP_DISABLE: u64 = 1 << 2;
    pub const NOT_TIMESTAMP_DISABLE: u64 = ~TIMESTAMP_DISABLE;
    pub inline fn isTIMESTAMP_DISABLE(self: Cr4) bool {
        return self.value & TIMESTAMP_DISABLE != 0;
    }

    /// Enables I/O breakpoint capability and enforces treatment of DR4 and DR5 x86_64.registers
    /// as reserved.
    pub const DEBUGGING_EXTENSIONS: u64 = 1 << 3;
    pub const NOT_DEBUGGING_EXTENSIONS: u64 = ~DEBUGGING_EXTENSIONS;
    pub inline fn isDEBUGGING_EXTENSIONS(self: Cr4) bool {
        return self.value & DEBUGGING_EXTENSIONS != 0;
    }

    /// Enables the use of 4MB physical frames; ignored in long mode.
    pub const PAGE_SIZE_EXTENSION: u64 = 1 << 4;
    pub const NOT_PAGE_SIZE_EXTENSION: u64 = ~PAGE_SIZE_EXTENSION;
    pub inline fn isPAGE_SIZE_EXTENSION(self: Cr4) bool {
        return self.value & PAGE_SIZE_EXTENSION != 0;
    }

    /// Enables physical address extension and 2MB physical frames; required in long mode.
    pub const PHYSICAL_ADDRESS_EXTENSION: u64 = 1 << 5;
    pub const NOT_PHYSICAL_ADDRESS_EXTENSION: u64 = ~PHYSICAL_ADDRESS_EXTENSION;
    pub inline fn isPHYSICAL_ADDRESS_EXTENSION(self: Cr4) bool {
        return self.value & PHYSICAL_ADDRESS_EXTENSION != 0;
    }

    /// Enables the machine-check exception mechanism.
    pub const MACHINE_CHECK_EXCEPTION: u64 = 1 << 6;
    pub const NOT_MACHINE_CHECK_EXCEPTION: u64 = ~MACHINE_CHECK_EXCEPTION;
    pub inline fn isMACHINE_CHECK_EXCEPTION(self: Cr4) bool {
        return self.value & MACHINE_CHECK_EXCEPTION != 0;
    }

    /// Enables the global-page mechanism, which allows to make page translations global
    /// to all processes.
    pub const PAGE_GLOBAL: u64 = 1 << 7;
    pub const NOT_PAGE_GLOBAL: u64 = ~PAGE_GLOBAL;
    pub inline fn isPAGE_GLOBAL(self: Cr4) bool {
        return self.value & PAGE_GLOBAL != 0;
    }

    /// Allows software running at any privilege level to use the RDPMC instruction.
    pub const PERFORMANCE_MONITOR_COUNTER: u64 = 1 << 8;
    pub const NOT_PERFORMANCE_MONITOR_COUNTER: u64 = ~PERFORMANCE_MONITOR_COUNTER;
    pub inline fn isPERFORMANCE_MONITOR_COUNTER(self: Cr4) bool {
        return self.value & PERFORMANCE_MONITOR_COUNTER != 0;
    }

    /// Enable the use of legacy SSE instructions; allows using FXSAVE/FXRSTOR for saving
    /// processor state of 128-bit media instructions.
    pub const OSFXSR: u64 = 1 << 9;
    pub const NOT_OSFXSR: u64 = ~OSFXSR;
    pub inline fn isOSFXSR(self: Cr4) bool {
        return self.value & OSFXSR != 0;
    }

    /// Enables the SIMD floating-point exception (#XF) for handling unmasked 256-bit and
    /// 128-bit media floating-point errors.
    pub const OSXMMEXCPT_ENABLE: u64 = 1 << 10;
    pub const NOT_OSXMMEXCPT_ENABLE: u64 = ~OSXMMEXCPT_ENABLE;
    pub inline fn isOSXMMEXCPT_ENABLE(self: Cr4) bool {
        return self.value & OSXMMEXCPT_ENABLE != 0;
    }

    /// Prevents the execution of the SGDT, SIDT, SLDT, SMSW, and STR instructions by
    /// user-mode software.
    pub const USER_MODE_INSTRUCTION_PREVENTION: u64 = 1 << 11;
    pub const NOT_USER_MODE_INSTRUCTION_PREVENTION: u64 = ~USER_MODE_INSTRUCTION_PREVENTION;
    pub inline fn isUSER_MODE_INSTRUCTION_PREVENTION(self: Cr4) bool {
        return self.value & USER_MODE_INSTRUCTION_PREVENTION != 0;
    }

    /// Enables 5-level paging on supported CPUs.
    pub const L5_PAGING: u64 = 1 << 12;
    pub const NOT_L5_PAGING: u64 = ~L5_PAGING;
    pub inline fn isL5_PAGING(self: Cr4) bool {
        return self.value & L5_PAGING != 0;
    }

    /// Enables VMX insturctions.
    pub const VIRTUAL_MACHINE_EXTENSIONS: u64 = 1 << 13;
    pub const NOT_VIRTUAL_MACHINE_EXTENSIONS: u64 = ~VIRTUAL_MACHINE_EXTENSIONS;
    pub inline fn isVIRTUAL_MACHINE_EXTENSIONS(self: Cr4) bool {
        return self.value & VIRTUAL_MACHINE_EXTENSIONS != 0;
    }

    /// Enables SMX instructions.
    pub const SAFER_MODE_EXTENSIONS: u64 = 1 << 14;
    pub const NOT_SAFER_MODE_EXTENSIONS: u64 = ~SAFER_MODE_EXTENSIONS;
    pub inline fn isSAFER_MODE_EXTENSIONS(self: Cr4) bool {
        return self.value & SAFER_MODE_EXTENSIONS != 0;
    }

    /// Enables software running in 64-bit mode at any privilege level to read and write
    /// the FS.base and GS.base hidden segment register state.
    pub const FSGSBASE: u64 = 1 << 16;
    pub const NOT_FSGSBASE: u64 = ~FSGSBASE;
    pub inline fn isFSGSBASE(self: Cr4) bool {
        return self.value & FSGSBASE != 0;
    }

    /// Enables process-context identifiers (PCIDs).
    pub const PCID: u64 = 1 << 17;
    pub const NOT_PCID: u64 = ~PCID;
    pub inline fn isPCID(self: Cr4) bool {
        return self.value & PCID != 0;
    }

    /// Enables extended processor state management instructions, including XGETBV and XSAVE.
    pub const OSXSAVE: u64 = 1 << 18;
    pub const NOT_OSXSAVE: u64 = ~OSXSAVE;
    pub inline fn isOSXSAVE(self: Cr4) bool {
        return self.value & OSXSAVE != 0;
    }

    /// Prevents the execution of instructions that reside in pages accessible by user-mode
    /// software when the processor is in supervisor-mode.
    pub const SUPERVISOR_MODE_EXECUTION_PROTECTION: u64 = 1 << 20;
    pub const NOT_SUPERVISOR_MODE_EXECUTION_PROTECTION: u64 = ~SUPERVISOR_MODE_EXECUTION_PROTECTION;
    pub inline fn isSUPERVISOR_MODE_EXECUTION_PROTECTION(self: Cr4) bool {
        return self.value & SUPERVISOR_MODE_EXECUTION_PROTECTION != 0;
    }

    /// Enables restrictions for supervisor-mode software when reading data from user-mode
    /// pages.
    pub const SUPERVISOR_MODE_ACCESS_PREVENTION: u64 = 1 << 21;
    pub const NOT_SUPERVISOR_MODE_ACCESS_PREVENTION: u64 = ~SUPERVISOR_MODE_ACCESS_PREVENTION;
    pub inline fn isSUPERVISOR_MODE_ACCESS_PREVENTION(self: Cr4) bool {
        return self.value & SUPERVISOR_MODE_ACCESS_PREVENTION != 0;
    }

    /// Enables 4-level paging to associate each linear address with a protection key.
    pub const PROTECTION_KEY: u64 = 1 << 22;
    pub const NOT_PROTECTION_KEY: u64 = ~PROTECTION_KEY;
    pub inline fn isPROTECTION_KEY(self: Cr4) bool {
        return self.value & PROTECTION_KEY != 0;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
