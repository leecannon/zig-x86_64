pub usingnamespace @import("addr.zig");

/// Representations of various x86 specific structures and descriptor tables.
pub const structures = @import("structures/structures.zig");

/// Access to various system and model specific registers.
pub const registers = @import("registers/registers.zig");

/// Special x86_64 instructions.
pub const instructions = @import("instructions/instructions.zig");

/// Various additional functionality in addition to the rust x86_64 crate
pub const additional = @import("additional/additional.zig");

pub const PrivilegeLevel = enum(u8) {
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
};

/// Result of the `cpuid` instruction.
pub const CpuidResult = struct {
    /// EAX register.
    eax: u32,

    /// EBX register.
    ebx: u32,

    /// ECX register.
    ecx: u32,

    /// EDX register.
    edx: u32,
};

/// Returns the result of the `cpuid` instruction for a given `leaf` (`EAX`) and sub_leaf (`ECX`) equal to zero.
/// See `cpuidWithSubleaf`
pub fn cpuid(leaf: u32) CpuidResult {
    return cpuidWithSubleaf(leaf, 0);
}

/// Returns the result of the `cpuid` instruction for a given `leaf` (`EAX`) and `sub_leaf` (`ECX`).
///
/// The highest-supported leaf value is returned by the first item of `cpuidMax(0)`.
/// For leaves containing sub-leaves, the second item returns the highest-supported sub-leaf value.
///
/// The CPUID Wikipedia page contains how to query which information using the `EAX` and `ECX` registers, and the interpretation of
/// the results returned in `EAX`, `EBX`, `ECX`, and `EDX`.
///
/// The references are:
/// - Intel 64 and IA-32 Architectures Software Developer's Manual Volume 2: Instruction Set Reference, A-Z
/// - AMD64 Architecture Programmer's Manual, Volume 3: General-Purpose and System Instructions
pub fn cpuidWithSubleaf(leaf: u32, sub_leaf: u32) CpuidResult {
    var eax: u32 = undefined;
    var ebx: u32 = undefined;
    var ecx: u32 = undefined;
    var edx: u32 = undefined;

    asm volatile ("mov %%rbx, %%rsi; cpuid; xchg %%rbx, %%rsi;"
        : [eax] "={eax}" (eax),
          [ebx] "={ebx}" (ebx),
          [ecx] "={ecx}" (ecx),
          [edx] "={edx}" (edx)
        : [eax] "{eax}" (leaf),
          [ecx] "{ecx}" (sub_leaf)
    );

    return CpuidResult{
        .eax = eax,
        .ebx = ebx,
        .ecx = ecx,
        .edx = edx,
    };
}

/// Returns the highest-supported `leaf` (`EAX`) and sub-leaf (`ECX`) `cpuid` values.
///
/// If `cpuid` is supported, and `leaf` is zero, then the first item contains the highest `leaf` value that `cpuid` supports.
/// For `leaf`s containing sub-leafs, the second item contains the highest-supported sub-leaf value.
pub fn cpuidMax(leaf: u32) [2]u32 {
    const result = cpuid(leaf);
    return [2]u32{
        result.eax,
        result.ebx,
    };
}

/// Get the id of the currently executing cpu/core (Local APIC id)
pub fn getCurrentCpuId() u16 {
    const bits = @import("bits.zig");
    return @truncate(u16, bits.getBits(cpuid(0x1).ebx, 24, 32));
}

comptime {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
