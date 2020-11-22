pub usingnamespace @import("addr.zig");

/// Representations of various x86 specific structures and descriptor tables.
pub const structures = @import("structures/structures.zig");

/// Special x86_64 instructions.
pub const instructions = @import("instructions/instructions.zig");

/// Access to various system and model specific registers.
pub const registers = @import("registers/registers.zig");

/// Various additional functionality in addition to the rust x86_64 crate
pub const additional = @import("additional/additional.zig");

pub const PrivilegeLevelError = error{InvalidPrivledgeLevel};

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

    pub fn from_u16(value: u16) PrivilegeLevelError!PrivilegeLevel {
        return switch (value) {
            0 => PrivilegeLevel.Ring0,
            1 => PrivilegeLevel.Ring1,
            2 => PrivilegeLevel.Ring2,
            3 => PrivilegeLevel.Ring3,
            else => error.InvalidPrivledgeLevel,
        };
    }

    pub fn to_u16(self: PrivilegeLevel) u16 {
        return @enumToInt(self);
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
pub fn cpuid_with_subleaf(leaf: u32, sub_leaf: u32) CpuidResult {
    var eax: u32 = undefined;
    var ebx: u32 = undefined;
    var ecx: u32 = undefined;
    var edx: u32 = undefined;

    asm volatile ("cpuid;"
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

/// See `cpuid_count`
pub fn cpuid(leaf: u32) CpuidResult {
    return cpuid_with_subleaf(leaf, 0);
}

/// Get the id of the currently executing cpu/core (Local APIC ID)
pub fn get_current_cpu_id() u16 {
    const bits = @import("bits.zig");
    const cpu_id = cpuid(0x1);
    return @truncate(u16, bits.get_bits(cpu_id.ebx, 24, 8));
}

/// Returns the highest-supported `leaf` (`EAX`) and sub-leaf (`ECX`) `cpuid`
/// values.
///
/// If `cpuid` is supported, and `leaf` is zero, then the first tuple argument
/// contains the highest `leaf` value that `cpuid` supports. For `leaf`s
/// containing sub-leafs, the second tuple argument contains the
/// highest-supported sub-leaf value.
///
/// See also `cpuid` and`cpuid_count`
pub fn get_cpuid_max(leaf: u32) CpuidMax {
    const result = cpuid(leaf);
    return CpuidMax{ .max_leaf = result.eax, .max_sub_leaf = result.ebx };
}

pub const CpuidMax = struct {
    max_leaf: u32,
    max_sub_leaf: u32,
};

test "" {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
