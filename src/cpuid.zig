const std = @import("std");

/// Result of the `cpuid` instruction.
pub const CpuidResult = struct {
    eax: u32, ebx: u32, ecx: u32, edx: u32
};

/// Returns the result of the `cpuid` instruction for a given `leaf` (`EAX`)
/// and
/// `sub_leaf` (`ECX`).
///
/// The highest-supported leaf and sub-leaf value is returned by `getCpuidMax(0)`
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

/// Calls `cpuid_with_subleaf` with subleaf set to 0
pub inline fn cpuid(leaf: u32) CpuidResult {
    return cpuid_with_subleaf(leaf, 0);
}

/// Get the id of the currently executing cpu/core (Local APIC id)
pub fn getCurrentCpuId() u16 {
    const bits = @import("bits.zig");
    const cpu_id = cpuid(0x1);
    return @truncate(u16, bits.getBits(cpu_id.ebx, 24, 8));
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
pub fn getCpuidMax(leaf: u32) CpuidMax {
    const result = cpuid(leaf);
    return CpuidMax{ .max_leaf = result.eax, .max_sub_leaf = result.ebx };
}

pub const CpuidMax = struct {
    max_leaf: u32,
    max_sub_leaf: u32,
};

test "" {
    std.testing.refAllDecls(@This());
}
