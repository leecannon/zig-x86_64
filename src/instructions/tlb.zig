usingnamespace @import("../common.zig");

/// Invalidate the given address in the TLB using the `invlpg` instruction.
pub fn flush(addr: VirtAddr) callconv(.Inline) void {
    asm volatile ("invlpg (%[addr])"
        :
        : [addr] "r" (addr.value)
        : "memory"
    );
}

/// Invalidate the TLB completely by reloading the CR3 register.
pub fn flushAll() callconv(.Inline) void {
    registers.control.Cr3.write(registers.control.Cr3.read());
}

/// The Invalidate PCID Command to execute.
pub const InvPicCommand = union(enum) {
    pub const AddressCommand = struct { virtAddr: VirtAddr, pcid: Pcid };

    /// The logical processor invalidates mappings—except global translations—for the linear address and PCID specified.
    address: AddressCommand,

    /// The logical processor invalidates all mappings—except global translations—associated with the PCID.
    single: Pcid,

    /// The logical processor invalidates all mappings—including global translations—associated with any PCID.
    all,

    /// The logical processor invalidates all mappings—except global translations—associated with any PCID.
    allExceptGlobal,
};

/// The INVPCID descriptor comprises 128 bits and consists of a PCID and a linear address.
/// For INVPCID type 0, the processor uses the full 64 bits of the linear address even outside 64-bit mode; the linear address is not used for other INVPCID types.
pub const InvpcidDescriptor = extern struct {
    address: u64,
    pcid: u64,
};

/// Structure of a PCID. A PCID has to be <= 4096 for x86_64.
pub const Pcid = packed struct {
    value: u12,

    /// Create a new PCID
    pub fn init(pcid: u12) Pcid {
        return .{
            .value = pcid,
        };
    }
};

/// Invalidate the given address in the TLB using the `invpcid` instruction.
///
/// ## Safety
/// This function is unsafe as it requires CPUID.(EAX=07H, ECX=0H):EBX.INVPCID to be 1.
pub fn flushPcid(command: InvPicCommand) void {
    var desc = InvpcidDescriptor{
        .address = 0,
        .pcid = 0,
    };

    const kind: u64 = blk: {
        switch (command) {
            .address => |address| {
                desc.address = address.virtAddr.value;
                desc.pcid = address.pcid.value;
                break :blk 0;
            },
            .single => |pcid| {
                desc.pcid = pcid.value;
                break :blk 1;
            },
            .all => break :blk 2,
            .allExceptGlobal => break :blk 3,
        }
    };

    asm volatile ("invpcid (%[desc]), %[kind]"
        :
        : [kind] "r" (kind),
          [desc] "r" (@ptrToInt(&desc))
        : "memory"
    );
}

comptime {
    std.testing.refAllDecls(@This());
}
