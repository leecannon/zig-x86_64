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
        @compileError("This requires an intrinsic that zig does not provide `_rdrand64_step`");
    }

    /// Uniformly sampled u32.
    /// May fail in rare circumstances or heavy load.
    pub inline fn get_u32(self: RdRand) ?u32 {
        @compileError("This requires an intrinsic that zig does not provide `_rdrand32_step`");
    }

    /// Uniformly sampled u16.
    /// May fail in rare circumstances or heavy load.
    pub inline fn get_u16(self: RdRand) ?u16 {
        @compileError("This requires an intrinsic that zig does not provide `_rdrand16_step`");
    }
};
