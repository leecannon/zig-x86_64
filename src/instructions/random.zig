usingnamespace @import("../common.zig");

/// Used to obtain random numbers using x86_64's RDRAND opcode
pub const RdRand = struct {
    /// Creates a RdRand if RDRAND is supported, null otherwise
    pub fn init() ?RdRand {
        // RDRAND support indicated by CPUID page 01h, ecx bit 30
        // https://en.wikipedia.org/wiki/RdRand#Overview
        if (getBit(x86_64.cpuid(0x1).ecx, 30)) {
            return RdRand{};
        }
        return null;
    }

    /// Uniformly sampled u64.
    /// May fail in rare circumstances or heavy load.
    pub fn getU64(self: RdRand) ?u64 {
        _ = self;
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
    pub fn getU32(self: RdRand) ?u32 {
        _ = self;
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
    pub fn getU16(self: RdRand) ?u16 {
        _ = self;
        var carry: u8 = undefined;
        const num: u16 = asm ("rdrand %[result]; setc %[carry]"
            : [result] "=r" (-> u16)
            : [carry] "qm" (&carry)
            : "cc"
        );
        return if (carry == 0) null else num;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Used to obtain seed numbers using x86_64's RDSEED opcode
pub const RdSeed = struct {
    /// Creates RdSeed if RDSEED is supported
    pub fn init() ?RdSeed {
        // RDSEED support indicated by CPUID page 07h, ebx bit 18
        if (getBit(x86_64.cpuid(0x7).ebx, 18)) {
            return RdSeed{};
        }
        return null;
    }

    /// Random u64 seed directly from entropy store.
    /// May fail in rare circumstances or heavy load.
    pub fn getU64(self: RdSeed) ?u64 {
        _ = self;
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
    pub fn getU32(self: RdSeed) ?u32 {
        _ = self;
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
    pub fn getU16(self: RdSeed) ?u16 {
        _ = self;
        var carry: u8 = undefined;
        const num: u16 = asm ("rdseed %[result]; setc %[carry]"
            : [result] "=r" (-> u16)
            : [carry] "qm" (&carry)
            : "cc"
        );
        return if (carry == 0) null else num;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
