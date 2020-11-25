usingnamespace @import("../common.zig");

/// An Interrupt Descriptor Table with 256 entries.
/// **IMPORTANT** Must be align(16)
///
/// The first 32 entries are used for CPU exceptions. These entries can be either accessed through
/// fields on this struct or through an index operation, e.g. `idt[0]` returns the
/// first entry, the entry for the `divide_error` exception. Note that the index access is
/// not possible for entries for which an error code is pushed.
///
/// The remaining entries are used for interrupts. They can be accesed through index
/// operations on the idt, e.g. `idt[32]` returns the first interrupt entry, which is the 32th IDT
/// entry).
pub const InterruptDescriptorTable = packed struct {
    /// A divide error (`#DE`) occurs when the denominator of a DIV instruction or
    /// an IDIV instruction is 0. A `#DE` also occurs if the result is too large to be
    /// represented in the destination.
    ///
    /// The saved instruction pointer points to the instruction that caused the `#DE`.
    ///
    /// The vector number of the `#DE` exception is 0.
    divide_error: HandlerFuncEntry,

    /// When the debug-exception mechanism is enabled, a `#DB` exception can occur under any
    /// of the following circumstances:
    ///
    /// <details>
    ///
    /// - Instruction execution.
    /// - Instruction single stepping.
    /// - Data read.
    /// - Data write.
    /// - I/O read.
    /// - I/O write.
    /// - Task switch.
    /// - Debug-register access, or general detect fault (debug register access when DR7.GD=1).
    /// - Executing the INT1 instruction (opcode 0F1h).
    ///
    /// </details>
    ///
    /// `#DB` conditions are enabled and disabled using the debug-control register, `DR7`
    /// and `RFLAGS.TF`.
    ///
    /// In the following cases, the saved instruction pointer points to the instruction that
    /// caused the `#DB`:
    ///
    /// - Instruction execution.
    /// - Invalid debug-register access, or general detect.
    ///
    /// In all other cases, the instruction that caused the `#DB` is completed, and the saved
    /// instruction pointer points to the instruction after the one that caused the `#DB`.
    ///
    /// The vector number of the `#DB` exception is 1.
    debug: HandlerFuncEntry,

    /// An non maskable interrupt exception (NMI) occurs as a result of system logic
    /// signaling a non-maskable interrupt to the processor.
    ///
    /// The processor recognizes an NMI at an instruction boundary.
    /// The saved instruction pointer points to the instruction immediately following the
    /// boundary where the NMI was recognized.
    ///
    /// The vector number of the NMI exception is 2.
    non_maskable_interrupt: HandlerFuncEntry,

    /// A breakpoint (`#BP`) exception occurs when an `INT3` instruction is executed. The
    /// `INT3` is normally used by debug software to set instruction breakpoints by replacing
    ///
    /// The saved instruction pointer points to the byte after the `INT3` instruction.
    ///
    /// The vector number of the `#BP` exception is 3.
    breakpoint: HandlerFuncEntry,

    /// An overflow exception (`#OF`) occurs as a result of executing an `INTO` instruction
    /// while the overflow bit in `RFLAGS` is set to 1.
    ///
    /// The saved instruction pointer points to the instruction following the `INTO`
    /// instruction that caused the `#OF`.
    ///
    /// The vector number of the `#OF` exception is 4.
    overflow: HandlerFuncEntry,

    /// A bound-range exception (`#BR`) exception can occur as a result of executing
    /// the `BOUND` instruction. The `BOUND` instruction compares an array index (first
    /// operand) with the lower bounds and upper bounds of an array (second operand).
    /// If the array index is not within the array boundary, the `#BR` occurs.
    ///
    /// The saved instruction pointer points to the `BOUND` instruction that caused the `#BR`.
    ///
    /// The vector number of the `#BR` exception is 5.
    bound_range_exceeded: HandlerFuncEntry,

    /// An invalid opcode exception (`#UD`) occurs when an attempt is made to execute an
    /// invalid or undefined opcode. The validity of an opcode often depends on the
    /// processor operating mode.
    ///
    /// <details><summary>A `#UD` occurs under the following conditions:</summary>
    ///
    /// - Execution of any reserved or undefined opcode in any mode.
    /// - Execution of the `UD2` instruction.
    /// - Use of the `LOCK` prefix on an instruction that cannot be locked.
    /// - Use of the `LOCK` prefix on a lockable instruction with a non-memory target location.
    /// - Execution of an instruction with an invalid-operand type.
    /// - Execution of the `SYSENTER` or `SYSEXIT` instructions in long mode.
    /// - Execution of any of the following instructions in 64-bit mode: `AAA`, `AAD`,
    ///   `AAM`, `AAS`, `BOUND`, `CALL` (opcode 9A), `DAA`, `DAS`, `DEC`, `INC`, `INTO`,
    ///   `JMP` (opcode EA), `LDS`, `LES`, `POP` (`DS`, `ES`, `SS`), `POPA`, `PUSH` (`CS`,
    ///   `DS`, `ES`, `SS`), `PUSHA`, `SALC`.
    /// - Execution of the `ARPL`, `LAR`, `LLDT`, `LSL`, `LTR`, `SLDT`, `STR`, `VERR`, or
    ///   `VERW` instructions when protected mode is not enabled, or when virtual-8086 mode
    ///   is enabled.
    /// - Execution of any legacy SSE instruction when `CR4.OSFXSR` is cleared to 0.
    /// - Execution of any SSE instruction (uses `YMM`/`XMM` registers), or 64-bit media
    /// instruction (uses `MMXTM` registers) when `CR0.EM` = 1.
    /// - Execution of any SSE floating-point instruction (uses `YMM`/`XMM` registers) that
    /// causes a numeric exception when `CR4.OSXMMEXCPT` = 0.
    /// - Use of the `DR4` or `DR5` debug registers when `CR4.DE` = 1.
    /// - Execution of `RSM` when not in `SMM` mode.
    ///
    /// </details>
    ///
    /// The saved instruction pointer points to the instruction that caused the `#UD`.
    ///
    /// The vector number of the `#UD` exception is 6.
    invalid_opcode: HandlerFuncEntry,

    /// A device not available exception (`#NM`) occurs under any of the following conditions:
    ///
    /// <details>
    ///
    /// - An `FWAIT`/`WAIT` instruction is executed when `CR0.MP=1` and `CR0.TS=1`.
    /// - Any x87 instruction other than `FWAIT` is executed when `CR0.EM=1`.
    /// - Any x87 instruction is executed when `CR0.TS=1`. The `CR0.MP` bit controls whether the
    ///   `FWAIT`/`WAIT` instruction causes an `#NM` exception when `TS=1`.
    /// - Any 128-bit or 64-bit media instruction when `CR0.TS=1`.
    ///
    /// </details>
    ///
    /// The saved instruction pointer points to the instruction that caused the `#NM`.
    ///
    /// The vector number of the `#NM` exception is 7.
    device_not_available: HandlerFuncEntry,

    /// A double fault (`#DF`) exception can occur when a second exception occurs during
    /// the handling of a prior (first) exception or interrupt handler.
    ///
    /// <details>
    ///
    /// Usually, the first and second exceptions can be handled sequentially without
    /// resulting in a `#DF`. In this case, the first exception is considered _benign_, as
    /// it does not harm the ability of the processor to handle the second exception. In some
    /// cases, however, the first exception adversely affects the ability of the processor to
    /// handle the second exception. These exceptions contribute to the occurrence of a `#DF`,
    /// and are called _contributory exceptions_. The following exceptions are contributory:
    ///
    /// - Invalid-TSS Exception
    /// - Segment-Not-Present Exception
    /// - Stack Exception
    /// - General-Protection Exception
    ///
    /// A double-fault exception occurs in the following cases:
    ///
    /// - If a contributory exception is followed by another contributory exception.
    /// - If a divide-by-zero exception is followed by a contributory exception.
    /// - If a page  fault is followed by another page fault or a contributory exception.
    ///
    /// If a third interrupting event occurs while transferring control to the `#DF` handler,
    /// the processor shuts down.
    ///
    /// </details>
    ///
    /// The returned error code is always zero. The saved instruction pointer is undefined,
    /// and the program cannot be restarted.
    ///
    /// The vector number of the `#DF` exception is 8.
    double_fault: HandlerDivergingWithErrorCodeFuncEntry,

    /// This interrupt vector is reserved. It is for a discontinued exception originally used
    /// by processors that supported external x87-instruction coprocessors. On those processors,
    /// the exception condition is caused by an invalid-segment or invalid-page access on an
    /// x87-instruction coprocessor-instruction operand. On current processors, this condition
    /// causes a general-protection exception to occur.
    coprocessor_segment_overrun: HandlerFuncEntry,

    /// An invalid TSS exception (`#TS`) occurs only as a result of a control transfer through
    /// a gate descriptor that results in an invalid stack-segment reference using an `SS`
    /// selector in the TSS.
    ///
    /// The returned error code is the `SS` segment selector. The saved instruction pointer
    /// points to the control-transfer instruction that caused the `#TS`.
    ///
    /// The vector number of the `#TS` exception is 10.
    invalid_tss: HandlerWithErrorCodeFuncEntry,

    /// An segment-not-present exception (`#NP`) occurs when an attempt is made to load a
    /// segment or gate with a clear present bit.
    ///
    /// The returned error code is the segment-selector index of the segment descriptor
    /// causing the `#NP` exception. The saved instruction pointer points to the instruction
    /// that loaded the segment selector resulting in the `#NP`.
    ///
    /// The vector number of the `#NP` exception is 11.
    segment_not_present: HandlerWithErrorCodeFuncEntry,

    /// An stack segment exception (`#SS`) can occur in the following situations:
    ///
    /// - Implied stack references in which the stack address is not in canonical
    ///   form. Implied stack references include all push and pop instructions, and any
    ///   instruction using `RSP` or `RBP` as a base register.
    /// - Attempting to load a stack-segment selector that references a segment descriptor
    ///   containing a clear present bit.
    /// - Any stack access that fails the stack-limit check.
    ///
    /// The returned error code depends on the cause of the `#SS`. If the cause is a cleared
    /// present bit, the error code is the corresponding segment selector. Otherwise, the
    /// error code is zero. The saved instruction pointer points to the instruction that
    /// caused the `#SS`.
    ///
    /// The vector number of the `#NP` exception is 12.
    stack_segment_fault: HandlerWithErrorCodeFuncEntry,

    /// A general protection fault (`#GP`) can occur in various situations. Common causes include:
    ///
    /// - Executing a privileged instruction while `CPL > 0`.
    /// - Writing a 1 into any register field that is reserved, must be zero (MBZ).
    /// - Attempting to execute an SSE instruction specifying an unaligned memory operand.
    /// - Loading a non-canonical base address into the `GDTR` or `IDTR`.
    /// - Using WRMSR to write a read-only MSR.
    /// - Any long-mode consistency-check violation.
    ///
    /// The returned error code is a segment selector, if the cause of the `#GP` is
    /// segment-related, and zero otherwise. The saved instruction pointer points to
    /// the instruction that caused the `#GP`.
    ///
    /// The vector number of the `#GP` exception is 13.
    general_protection_fault: HandlerWithErrorCodeFuncEntry,

    /// A page fault (`#PF`) can occur during a memory access in any of the following situations:
    ///
    /// - A page-translation-table entry or physical page involved in translating the memory
    ///   access is not present in physical memory. This is indicated by a cleared present
    ///   bit in the translation-table entry.
    /// - An attempt is made by the processor to load the instruction TLB with a translation
    ///   for a non-executable page.
    /// - The memory access fails the paging-protection checks (user/supervisor, read/write,
    ///   or both).
    /// - A reserved bit in one of the page-translation-table entries is set to 1. A `#PF`
    ///   occurs for this reason only when `CR4.PSE=1` or `CR4.PAE=1`.
    ///
    /// The virtual (linear) address that caused the `#PF` is stored in the `CR2` register.
    /// The saved instruction pointer points to the instruction that caused the `#PF`.
    ///
    /// The page-fault error code is described by the
    /// [`PageFaultErrorCode`](struct.PageFaultErrorCode.html) struct.
    ///
    /// The vector number of the `#PF` exception is 14.
    page_fault: PageFaultHandlerFuncEntry,

    /// vector nr. 15
    reserved_1: HandlerFuncEntry,

    /// The x87 Floating-Point Exception-Pending exception (`#MF`) is used to handle unmasked x87
    /// floating-point exceptions. In 64-bit mode, the x87 floating point unit is not used
    /// anymore, so this exception is only relevant when executing programs in the 32-bit
    /// compatibility mode.
    ///
    /// The vector number of the `#MF` exception is 16.
    x87_floating_point: HandlerFuncEntry,

    /// An alignment check exception (`#AC`) occurs when an unaligned-memory data reference
    /// is performed while alignment checking is enabled. An `#AC` can occur only when CPL=3.
    ///
    /// The returned error code is always zero. The saved instruction pointer points to the
    /// instruction that caused the `#AC`.
    ///
    /// The vector number of the `#AC` exception is 17.
    alignment_check: HandlerWithErrorCodeFuncEntry,

    /// The machine check exception (`#MC`) is model specific. Processor implementations
    /// are not required to support the `#MC` exception, and those implementations that do
    /// support `#MC` can vary in how the `#MC` exception mechanism works.
    ///
    /// There is no reliable way to restart the program.
    ///
    /// The vector number of the `#MC` exception is 18.
    machine_check: HandlerDivergingFuncEntry,

    /// The SIMD Floating-Point Exception (`#XF`) is used to handle unmasked SSE
    /// floating-point exceptions. The SSE floating-point exceptions reported by
    /// the `#XF` exception are (including mnemonics):
    ///
    /// - IE: Invalid-operation exception (also called #I).
    /// - DE: Denormalized-operand exception (also called #D).
    /// - ZE: Zero-divide exception (also called #Z).
    /// - OE: Overflow exception (also called #O).
    /// - UE: Underflow exception (also called #U).
    /// - PE: Precision exception (also called #P or inexact-result exception).
    ///
    /// The saved instruction pointer points to the instruction that caused the `#XF`.
    ///
    /// The vector number of the `#XF` exception is 19.
    simd_floating_point: HandlerFuncEntry,

    /// vector nr. 20
    virtualization: HandlerFuncEntry,

    /// vector nr. 21-29
    reserved_2: [9]HandlerFuncEntry,

    /// The Security Exception (`#SX`) signals security-sensitive events that occur while
    /// executing the VMM, in the form of an exception so that the VMM may take appropriate
    /// action. (A VMM would typically intercept comparable sensitive events in the guest.)
    /// In the current implementation, the only use of the `#SX` is to redirect external INITs
    /// into an exception so that the VMM may — among other possibilities.
    ///
    /// The only error code currently defined is 1, and indicates redirection of INIT has occurred.
    ///
    /// The vector number of the ``#SX`` exception is 30.
    security_exception: HandlerWithErrorCodeFuncEntry,

    /// vector nr. 31
    reserved_3: HandlerFuncEntry,

    /// User-defined interrupts can be initiated either by system logic or software. They occur
    /// when:
    ///
    /// - System logic signals an external interrupt request to the processor. The signaling
    ///   mechanism and the method of communicating the interrupt vector to the processor are
    ///   implementation dependent.
    /// - Software executes an `INTn` instruction. The `INTn` instruction operand provides
    ///   the interrupt vector number.
    ///
    /// Both methods can be used to initiate an interrupt into vectors 0 through 255. However,
    /// because vectors 0 through 31 are defined or reserved by the AMD64 architecture,
    /// software should not use vectors in this range for purposes other than their defined use.
    ///
    /// The saved instruction pointer depends on the interrupt source:
    ///
    /// - External interrupts are recognized on instruction boundaries. The saved instruction
    ///   pointer points to the instruction immediately following the boundary where the
    ///   external interrupt was recognized.
    /// - If the interrupt occurs as a result of executing the INTn instruction, the saved
    ///   instruction pointer points to the instruction after the INTn.
    interrupts: [256 - 32]HandlerFuncEntry,

    pub fn init() InterruptDescriptorTable {
        return InterruptDescriptorTable{
            .divide_error = HandlerFuncEntry.missing(),
            .debug = HandlerFuncEntry.missing(),
            .non_maskable_interrupt = HandlerFuncEntry.missing(),
            .breakpoint = HandlerFuncEntry.missing(),
            .overflow = HandlerFuncEntry.missing(),
            .bound_range_exceeded = HandlerFuncEntry.missing(),
            .invalid_opcode = HandlerFuncEntry.missing(),
            .device_not_available = HandlerFuncEntry.missing(),
            .double_fault = HandlerDivergingWithErrorCodeFuncEntry.missing(),
            .coprocessor_segment_overrun = HandlerFuncEntry.missing(),
            .invalid_tss = HandlerWithErrorCodeFuncEntry.missing(),
            .segment_not_present = HandlerWithErrorCodeFuncEntry.missing(),
            .stack_segment_fault = HandlerWithErrorCodeFuncEntry.missing(),
            .general_protection_fault = HandlerWithErrorCodeFuncEntry.missing(),
            .page_fault = PageFaultHandlerFuncEntry.missing(),
            .reserved_1 = HandlerFuncEntry.missing(),
            .x87_floating_point = HandlerFuncEntry.missing(),
            .alignment_check = HandlerWithErrorCodeFuncEntry.missing(),
            .machine_check = HandlerDivergingFuncEntry.missing(),
            .simd_floating_point = HandlerFuncEntry.missing(),
            .virtualization = HandlerFuncEntry.missing(),
            .reserved_2 = [_]HandlerFuncEntry{HandlerFuncEntry.missing()} ** 9,
            .security_exception = HandlerWithErrorCodeFuncEntry.missing(),
            .reserved_3 = HandlerFuncEntry.missing(),
            .interrupts = [_]HandlerFuncEntry{HandlerFuncEntry.missing()} ** (256 - 32),
        };
    }

    /// Resets all entries of this IDT in place.
    pub inline fn reset(self: *InterruptDescriptorTable) void {
        self.* = InterruptDescriptorTable.init();
    }

    /// Loads the IDT in the CPU using the `lidt` command.
    pub fn load(self: *InterruptDescriptorTable) void {
        const ptr = structures.DescriptorTablePointer{
            .base = @ptrToInt(self),
            .limit = @as(u16, @sizeOf(InterruptDescriptorTable) - 1),
        };

        instructions.tables.lidt(&ptr);
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "InterruptDescriptorTable" {
    std.testing.expectEqual(@bitSizeOf(u64) * 2 * 256, @bitSizeOf(InterruptDescriptorTable));
    std.testing.expectEqual(@sizeOf(u64) * 2 * 256, @sizeOf(InterruptDescriptorTable));
}

pub const HandlerFunc = fn (interruptStackFrame: *InterruptStackFrame) callconv(.Interrupt) void;
pub const HandlerFuncEntry = Entry(HandlerFunc);

pub const HandlerWithErrorCodeFunc = fn (interruptStackFrame: *InterruptStackFrame, error_code: u64) callconv(.Interrupt) void;
pub const HandlerWithErrorCodeFuncEntry = Entry(HandlerWithErrorCodeFunc);

pub const PageFaultHandlerFunc = fn (interruptStackFrame: *InterruptStackFrame, page_fault_error_code: u64) callconv(.Interrupt) void;
pub const PageFaultHandlerFuncEntry = Entry(PageFaultHandlerFunc);

pub const HandlerDivergingFunc = fn (interruptStackFrame: *InterruptStackFrame) callconv(.Interrupt) noreturn;
pub const HandlerDivergingFuncEntry = Entry(HandlerDivergingFunc);

pub const HandlerDivergingWithErrorCodeFunc = fn (interruptStackFrame: *InterruptStackFrame, error_code: u64) callconv(.Interrupt) noreturn;
pub const HandlerDivergingWithErrorCodeFuncEntry = Entry(HandlerDivergingWithErrorCodeFunc);

fn Entry(comptime handler_type: type) type {
    comptime {
        if (handler_type != HandlerFunc and handler_type != HandlerWithErrorCodeFunc and handler_type != PageFaultHandlerFunc and handler_type != HandlerDivergingFunc and handler_type != HandlerDivergingWithErrorCodeFunc) {
            @compileError("Non-Interupt handler func type given");
        }
    }

    return packed struct {
        const Self = @This();

        pointer_low: u16,
        gdt_selector: u16,
        options: EntryOptions,
        pointer_middle: u16,
        pointer_high: u32,
        reserved: u32,

        /// Creates a non-present IDT entry (but sets the must-be-one bits).
        pub fn missing() Self {
            return .{
                .pointer_low = 0,
                .gdt_selector = 0,
                .options = EntryOptions.minimal(),
                .pointer_middle = 0,
                .pointer_high = 0,
                .reserved = 0,
            };
        }

        pub fn set_handler(self: *Self, handler: handler_type) void {
            const addr = @ptrToInt(handler);

            self.pointer_low = @truncate(u16, addr);
            self.pointer_middle = @truncate(u16, (addr >> 16));
            self.pointer_high = @truncate(u32, (addr >> 32));

            self.gdt_selector = instructions.segmentation.get_cs().selector;

            self.options.set_present(true);
        }

        test "" {
            std.testing.refAllDecls(@This());
        }
    };
}

fn dummy_fn(interruptStackFrame: *InterruptStackFrame) callconv(.Interrupt) void {}

test "Entry" {
    var a = HandlerFuncEntry.missing();
    a.set_handler(dummy_fn);
}

test "EntrySize" {
    std.testing.expectEqual(@bitSizeOf(u64) * 2, @bitSizeOf(HandlerFuncEntry));
    std.testing.expectEqual(@sizeOf(u64) * 2, @sizeOf(HandlerFuncEntry));

    std.testing.expectEqual(@bitSizeOf(u64) * 2, @bitSizeOf(HandlerWithErrorCodeFuncEntry));
    std.testing.expectEqual(@sizeOf(u64) * 2, @sizeOf(HandlerWithErrorCodeFuncEntry));

    std.testing.expectEqual(@bitSizeOf(u64) * 2, @bitSizeOf(PageFaultHandlerFuncEntry));
    std.testing.expectEqual(@sizeOf(u64) * 2, @sizeOf(PageFaultHandlerFuncEntry));

    std.testing.expectEqual(@bitSizeOf(u64) * 2, @bitSizeOf(HandlerDivergingFuncEntry));
    std.testing.expectEqual(@sizeOf(u64) * 2, @sizeOf(HandlerDivergingFuncEntry));

    std.testing.expectEqual(@bitSizeOf(u64) * 2, @bitSizeOf(HandlerDivergingWithErrorCodeFuncEntry));
    std.testing.expectEqual(@sizeOf(u64) * 2, @sizeOf(HandlerDivergingWithErrorCodeFuncEntry));
}

/// Represents the options field of an IDT entry.
pub const EntryOptions = packed struct {
    value: u16,

    /// Creates a minimal options field with all the must-be-one bits set.
    pub inline fn minimal() EntryOptions {
        return EntryOptions{ .value = 0b1110_0000_0000 };
    }

    /// Set or reset the preset bit.
    pub inline fn set_present(self: *EntryOptions, present: bool) void {
        set_bit(&self.value, 15, present);
    }

    /// Let the CPU disable hardware interrupts when the handler is invoked. By default,
    /// interrupts are disabled on handler invocation.
    pub inline fn disable_interupts(self: *EntryOptions, disable: bool) void {
        set_bit(&self.value, 8, !disable);
    }

    /// Set the required privilege level (DPL) for invoking the handler. The DPL can be 0, 1, 2,
    /// or 3, the default is 0. If CPL < DPL, a general protection fault occurs.
    pub inline fn set_privledge_level(self: *EntryOptions, dpl: PrivilegeLevel) void {
        set_bits(&self.value, 13, 2, dpl.to_u16());
    }

    /// Assigns a Interrupt Stack Table (IST) stack to this handler. The CPU will then always
    /// switch to the specified stack before the handler is invoked. This allows kernels to
    /// recover from corrupt stack pointers (e.g., on kernel stack overflow).
    ///
    /// An IST stack is specified by an IST index between 0 and 6 (inclusive). Using the same
    /// stack for multiple interrupts can be dangerous when nested interrupts are possible.
    pub inline fn set_stack_index(self: *EntryOptions, index: u16) void {
        // The hardware IST index starts at 1, but our software IST index
        // starts at 0. Therefore we need to add 1 here.
        set_bits(&self.value, 0, 3, index + 1);
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "EntryOptions" {
    std.testing.expectEqual(@bitSizeOf(u16), @bitSizeOf(EntryOptions));
    std.testing.expectEqual(@sizeOf(u16), @sizeOf(EntryOptions));
}

/// Represents the interrupt stack frame pushed by the CPU on interrupt or exception entry.
pub const InterruptStackFrame = packed struct {
    /// The stack segment descriptor at the time of the interrupt (often zero in 64-bit mode).
    instruction_pointer: VirtAddr,
    code_segment: u64,
    cpu_flags: u64,
    stack_pointer: VirtAddr,
    stack_segment: u64,

    pub fn format(value: InterruptStackFrame, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try std.fmt.format(writer, "InterruptStackFrame( instruction_pointer: {}, code_segment: {}, cpu_flags: 0x{x}, stack_pointer: {}, stack_segment: {} )", .{ value.instruction_pointer, value.code_segment, value.cpu_flags, value.stack_pointer, value.stack_segment });
    }
};

test "InterruptStackFrame" {
    std.testing.expectEqual(@bitSizeOf(u64) * 5, @bitSizeOf(InterruptStackFrame));
    std.testing.expectEqual(@sizeOf(u64) * 5, @sizeOf(InterruptStackFrame));
}

// Commented out is a packed struct representing a Page Fault error code, however due to https://github.com/ziglang/zig/issues/1481 it cannot be used

// /// Describes an page fault error code.
// pub const PageFaultErrorCode = packed struct {
//     /// If this flag is set, the page fault was caused by a page-protection violation,
//     /// else the page fault was caused by a not-present page.
//     PROTECTION_VIOLATION: bool,
//     /// If this flag is set, the memory access that caused the page fault was a write.
//     /// Else the access that caused the page fault is a memory read. This bit does not
//     /// necessarily indicate the cause of the page fault was a read or write violation.
//     CAUSED_BY_WRITE: bool,
//     /// If this flag is set, an access in user mode (CPL=3) caused the page fault. Else
//     /// an access in supervisor mode (CPL=0, 1, or 2) caused the page fault. This bit
//     /// does not necessarily indicate the cause of the page fault was a privilege violation.
//     USER_MODE: bool,
//     /// If this flag is set, the page fault is a result of the processor reading a 1 from
//     /// a reserved field within a page-translation-table entry.
//     MALFORMED_TABLE: bool,
//     /// If this flag is set, it indicates that the access that caused the page fault was an
//     /// instruction fetch.
//     INSTRUCTION_FETCH: bool,

//     _padding1: bool,
//     _padding2: bool,
//     _padding3: bool,

//     _padding_a: u8,
//     _padding_b: u16,
//     _padding_c: u32,
// };

// test "PageFaultErrorCode" {
//     std.testing.expectEqual(@bitSizeOf(u64), @bitSizeOf(PageFaultErrorCode));
//     std.testing.expectEqual(@sizeOf(u64), @sizeOf(PageFaultErrorCode));
// }

/// If this flag is set, the page fault was caused by a page-protection violation,
/// else the page fault was caused by a not-present page.
pub const PAGE_FAULT_PROTECTION_VIOLATION: u64 = 1;
/// If this flag is set, the memory access that caused the page fault was a write.
/// Else the access that caused the page fault is a memory read. This bit does not
/// necessarily indicate the cause of the page fault was a read or write violation.
pub const PAGE_FAULT_CAUSED_BY_WRITE: u64 = 1 << 1;
/// If this flag is set, an access in user mode (CPL=3) caused the page fault. Else
/// an access in supervisor mode (CPL=0, 1, or 2) caused the page fault. This bit
/// does not necessarily indicate the cause of the page fault was a privilege violation.
pub const PAGE_FAULT_USER_MODE: u64 = 1 << 2;
/// If this flag is set, the page fault is a result of the processor reading a 1 from
/// a reserved field within a page-translation-table entry.
pub const PAGE_FAULT_MALFORMED_TABLE: u64 = 1 << 3;
/// If this flag is set, it indicates that the access that caused the page fault was an
/// instruction fetch.
pub const PAGE_FAULT_INSTRUCTION_FETCH: u64 = 1 << 4;

test "" {
    std.testing.refAllDecls(@This());
}
