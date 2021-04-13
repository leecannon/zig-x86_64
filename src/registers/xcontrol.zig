usingnamespace @import("../common.zig");

/// Extended feature enable mask register
pub const XCr0 = struct {
    value: u64,

    /// Read the current set of XCr0 flags.
    pub fn read() XCr0 {
        return .{ .value = readRaw() & ALL };
    }

    /// Read the current raw XCr0 value.
    pub fn readRaw() u64 {
        var high: u32 = undefined;
        var low: u32 = undefined;

        asm ("xor %%rcx, %%rcx; xgetbv"
            : [low] "={rax}" (low),
              [high] "={rdx}" (high)
            :
            : "rcx"
        );

        return (@as(u64, high) << 32) | @as(u64, low);
    }

    /// Write XCr0 flags.
    ///
    /// Preserves the value of reserved fields.
    pub fn write(self: XCr0) void {
        writeRaw(self.value | (readRaw() & NOT_ALL));
    }

    /// Write raw XCr0 flags.
    ///
    /// Does _not_ preserve any values, including reserved fields.
    pub fn writeRaw(value: u64) void {
        var high: u32 = @truncate(u32, value >> 32);
        var low: u32 = @truncate(u32, value);

        asm volatile ("xor %%ecx, %%ecx; xsetbv"
            :
            : [low] "{eax}" (low),
              [high] "{edx}" (high)
            : "ecx"
        );
    }

    pub const ALL: u64 = X87 | SSE | YMM | MPK | LWP;
    pub const NOT_ALL: u64 = ~ALL;

    /// Enables x87 FPU
    pub const X87: u64 = 1;
    pub const NOT_X87: u64 = ~X87;

    /// Enables 128-bit (legacy) SSE
    /// Must be set to enable AVX and YMM
    pub const SSE: u64 = 1 << 1;
    pub const NOT_SSE: u64 = ~SSE;

    /// Enables 256-bit SSE
    /// Must be set to enable AVX
    pub const YMM: u64 = 1 << 2;
    pub const NOT_YMM: u64 = ~YMM;

    /// When set, PKRU state management is supported by
    /// ZSAVE/XRSTOR
    pub const MPK: u64 = 1 << 9;
    pub const NOT_MPK: u64 = ~MPK;

    /// When set the Lightweight Profiling extensions are enabled
    pub const LWP: u64 = 1 << 62;
    pub const NOT_LWP: u64 = ~LWP;

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
