usingnamespace @import("../common.zig");

/// Used to obtain random numbers using x86_64's RDRAND opcode
pub const RdRand = struct {
    /// Creates RdRand if RDRAND is supported
    pub inline fn new() ?RdRand {
        // RDRAND support indicated by CPUID page 01h, ecx bit 30
        // https://en.wikipedia.org/wiki/RdRand#Overview
        const cpu_id = cpuid(0x1);
        if (cpu_id.ecx & (1 << 30) != 0) {
            return RdRand{};
        }
        return null;
    }

    /// Uniformly sampled u64.
    /// May fail in rare circumstances or heavy load.
    pub inline fn get_u64(self: RdRand) ?u64 {
        var carry: u8 = undefined;
        const num: u64 = asm ("rdrand %[result]; setc %[carry]"
            : [result] "=r" (-> u64)
            : [carry] "qm" (&carry)
            : "cc"
        );
        return if (carry == 0) null else num;
    }

    /// Uniformly sampled u32.
    /// May fail in rare circumstances or heavy load.
    pub inline fn get_u32(self: RdRand) ?u32 {
        var carry: u8 = undefined;
        const num: u32 = asm ("rdrand %[result]; setc %[carry]"
            : [result] "=r" (-> u32)
            : [carry] "qm" (&carry)
            : "cc"
        );
        return if (carry == 0) null else num;
    }

    /// Uniformly sampled u16.
    /// May fail in rare circumstances or heavy load.
    pub inline fn get_u16(self: RdRand) ?u16 {
        var carry: u8 = undefined;
        const num: u16 = asm ("rdrand %[result]; setc %[carry]"
            : [result] "=r" (-> u16)
            : [carry] "qm" (&carry)
            : "cc"
        );
        return if (carry == 0) null else num;
    }
};

/// Used to obtain seed numbers using x86_64's RDSEED opcode
pub const RdSeed = struct {
    /// Creates RdSeed if RDSEED is supported
    pub inline fn new() ?RdSeed {
        // RDSEED support indicated by CPUID page 07h, ebx bit 18
        // https://en.wikipedia.org/wiki/RdRand#Overview
        const cpu_id = cpuid(0x7);
        if (cpu_id.ebx & (1 << 18) != 0) {
            return RdSeed{};
        }
        return null;
    }

    /// Random u64 seed directly from entropy store.
    /// May fail in rare circumstances or heavy load.
    pub inline fn get_u64(self: RdSeed) ?u64 {
        var carry: u8 = undefined;
        const num: u64 = asm ("rdseed %[result]; setc %[carry]"
            : [result] "=r" (-> u64)
            : [carry] "qm" (&carry)
            : "cc"
        );
        return if (carry == 0) null else num;
    }

    /// Random u32 seed directly from entropy store.
    /// May fail in rare circumstances or heavy load.
    pub inline fn get_u32(self: RdSeed) ?u32 {
        var carry: u8 = undefined;
        const num: u32 = asm ("rdseed %[result]; setc %[carry]"
            : [result] "=r" (-> u32)
            : [carry] "qm" (&carry)
            : "cc"
        );
        return if (carry == 0) null else num;
    }

    /// Random u16 seed directly from entropy store.
    /// May fail in rare circumstances or heavy load.
    pub inline fn get_u16(self: RdSeed) ?u16 {
        var carry: u8 = undefined;
        const num: u16 = asm ("rdseed %[result]; setc %[carry]"
            : [result] "=r" (-> u16)
            : [carry] "qm" (&carry)
            : "cc"
        );
        return if (carry == 0) null else num;
    }
};

test "" {
    std.meta.refAllDecls(@This());
}
