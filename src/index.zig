pub usingnamespace @import("addr.zig");

pub const structures = @import("structures/structures.zig");
pub const instructions = @import("instructions/instructions.zig");
pub const registers = @import("registers/registers.zig");

pub const PrivilegeLevel = packed enum(u8) {
    /// Privilege-level 0 (most privilege): This level is used by critical system-software
    /// components that require direct access to, and control over, all processor and system
    /// resources. This can include BIOS, memory-management functions, and interrupt handlers.
    Ring0 = 0,

    /// Privilege-level 1 (moderate privilege): This level is used by less-critical system-
    /// software services that can access and control a limited scope of processor and system
    /// resources. Software running at these privilege levels might include some device drivers
    /// and library routines. The actual privileges of this level are defined by the
    /// operating system.
    Ring1 = 1,

    /// Privilege-level 2 (moderate privilege): Like level 1, this level is used by
    /// less-critical system-software services that can access and control a limited scope of
    /// processor and system resources. The actual privileges of this level are defined by the
    /// operating system.
    Ring2 = 2,

    /// Privilege-level 3 (least privilege): This level is used by application software.
    /// Software running at privilege-level 3 is normally prevented from directly accessing
    /// most processor and system resources. Instead, applications request access to the
    /// protected processor and system resources by calling more-privileged service routines
    /// to perform the accesses.
    Ring3 = 3,

    pub fn from_u16(value: u16) PrivilegeLevel {
        return switch (value) {
            0 => PrivilegeLevel.Ring0,
            1 => PrivilegeLevel.Ring1,
            2 => PrivilegeLevel.Ring2,
            3 => PrivilegeLevel.Ring3,
            else => @panic("{} is not a valid privilege level", .{value}),
        };
    }
};

/// Result of the `cpuid` instruction.
pub const CpuidResult = struct {
    eax: u32, ebx: u32, ecx: u32, edx: u32
};

/// Returns the result of the `cpuid` instruction for a given `leaf` (`EAX`)
/// and
/// `sub_leaf` (`ECX`).
///
/// The highest-supported leaf and sub-leaf value is returned by `get_cpuid_max(0)`
///
/// The [CPUID Wikipedia page][wiki_cpuid] contains how to query which
/// information using the `EAX` and `ECX` registers, and the interpretation of
/// the results returned in `EAX`, `EBX`, `ECX`, and `EDX`.
///
/// The references are:
/// - [Intel 64 and IA-32 Architectures Software Developer's Manual Volume 2:
///   Instruction Set Reference, A-Z][intel64_ref].
/// - [AMD64 Architecture Programmer's Manual, Volume 3: General-Purpose and
///   System Instructions][amd64_ref].
///
/// [wiki_cpuid]: https://en.wikipedia.org/wiki/CPUID
/// [intel64_ref]: http://www.intel.de/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf
/// [amd64_ref]: http://support.amd.com/TechDocs/24594.pdf
pub inline fn cpuid_count(leaf: u32, sub_leaf: u32) CpuidResult {
    var eax: u32 = undefined;
    var ebx: u32 = undefined;
    var ecx: u32 = undefined;
    var edx: u32 = undefined;

    // Unsure if below is an issue in zig? (Copied from rust x86_64)
    // x86-64 uses %rbx as the base register, so preserve it.
    // This works around a bug in LLVM with ASAN enabled:
    // https://bugs.llvm.org/show_bug.cgi?id=17907
    asm volatile ("mov %%rbx, %%rsi; cpuid; xchg %%rbx, %%rsi"
        : [eax] "={eax}" (eax),
          [ebx] "={ebx}" (ebx),
          [ecx] "={ecx}" (ecx),
          [edx] "={edx}" (edx)
        : [leaf] "{eax}" (leaf),
          [ecx] "{ecx}" (sub_leaf)
    );

    return CpuidResult{
        .eax = eax,
        .ebx = ebx,
        .ecx = ecx,
        .edx = edx,
    };
}

/// See `cpuid_count`
pub inline fn cpuid(leaf: u32) CpuidResult {
    return cpuid_count(leaf, 0);
}

/// Returns the highest-supported `leaf` (`EAX`) and sub-leaf (`ECX`) `cpuid`
/// values.
///
/// If `cpuid` is supported, and `leaf` is zero, then the first tuple argument
/// contains the highest `leaf` value that `cpuid` supports. For `leaf`s
/// containing sub-leafs, the second tuple argument contains the
/// highest-supported sub-leaf value.
///
/// See also `__cpuid` and`cpuid_count`
pub inline fn get_cpuid_max(leaf: u32) CpuidMax {
    const result = cpuid(leaf);
    return CpuidMax{ .max_leaf = result.eax, .max_sub_leaf = result.ebx };
}

pub const CpuidMax = struct {
    max_leaf: u32,
    max_sub_leaf: u32,
};

test "" {
    // Test all files
    const test_bits = @import("bits.zig");
    const test_addr = @import("addr.zig");

    const test_instructions = @import("instructions/instructions.zig");
    const interrupts = test_instructions.interrupts;
    const port = test_instructions.port;
    const random = test_instructions.random;

    const test_registers = @import("registers/registers.zig");
    const rflags = test_registers.rflags;
    const control = @import("registers/control.zig");

    const test_structures = @import("structures/structures.zig");
    const paging = test_structures.paging;
}
