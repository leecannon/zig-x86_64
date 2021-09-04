const x86_64 = @import("../index.zig");
const bitjuggle = @import("bitjuggle");
const std = @import("std");
const formatWithoutFields = @import("../common.zig").formatWithoutFields;

/// Extended feature enable mask register
pub const XCr0 = packed struct {
    /// Enables x87 FPU
    x87: bool,

    /// Enables 128-bit (legacy) SSE
    /// Must be set to enable AVX and YMM
    sse: bool,

    /// Enables 256-bit SSE
    /// Must be set to enable AVX
    avx: bool,

    /// When set, MPX instructions are enabled and the bound registers BND0-BND3 can be managed by XSAVE.
    bndreg: bool,

    /// When set, MPX instructions can be executed and XSAVE can manage the BNDCFGU and BNDSTATUS registers.
    bndcsr: bool,

    /// If set, AVX-512 instructions can be executed and XSAVE can manage the K0-K7 mask registers.
    opmask: bool,

    /// If set, AVX-512 instructions can be executed and XSAVE can be used to manage the upper halves of the lower ZMM registers.
    zmm_hi256: bool,

    /// If set, AVX-512 instructions can be executed and XSAVE can manage the upper ZMM registers.
    hi16_zmm: bool,

    z_reserved8: bool,

    /// When set, PKRU state management is supported by XSAVE/XRSTOR
    mpk: bool,

    z_reserved10_15: u6,
    z_reserved16_47: u32,
    z_reserved48_55: u8,
    z_reserved56_61: u6,

    /// When set the Lightweight Profiling extensions are enabled
    lwp: bool,

    z_reserved63: bool,

    /// Read the current set of XCr0 flags.
    pub fn read() XCr0 {
        return XCr0.fromU64(readRaw());
    }

    /// Read the current raw XCr0 value.
    fn readRaw() u64 {
        var high: u32 = undefined;
        var low: u32 = undefined;

        asm ("xor %%rcx, %%rcx; xgetbv"
            : [low] "={rax}" (low),
              [high] "={rdx}" (high),
            :
            : "rcx"
        );

        return (@as(u64, high) << 32) | @as(u64, low);
    }

    /// Write XCr0 flags.
    ///
    /// Preserves the value of reserved fields.
    pub fn write(self: XCr0) void {
        writeRaw(self.toU64() | (readRaw() & ALL_RESERVED));
    }

    /// Write raw XCr0 flags.
    ///
    /// Does _not_ preserve any values, including reserved fields.
    fn writeRaw(value: u64) void {
        var high: u32 = @truncate(u32, value >> 32);
        var low: u32 = @truncate(u32, value);

        asm volatile ("xor %%ecx, %%ecx; xsetbv"
            :
            : [low] "{eax}" (low),
              [high] "{edx}" (high),
            : "ecx"
        );
    }

    const ALL_RESERVED: u64 = blk: {
        var flags = std.mem.zeroes(XCr0);
        flags.z_reserved8 = true;
        flags.z_reserved10_15 = std.math.maxInt(u6);
        flags.z_reserved16_47 = std.math.maxInt(u32);
        flags.z_reserved48_55 = std.math.maxInt(u8);
        flags.z_reserved56_61 = std.math.maxInt(u6);
        flags.z_reserved63 = true;
        break :blk @bitCast(u64, flags);
    };

    const ALL_NOT_RESERVED: u64 = ~ALL_RESERVED;

    pub fn fromU64(value: u64) XCr0 {
        return @bitCast(XCr0, value & ALL_NOT_RESERVED);
    }

    pub fn toU64(self: XCr0) u64 {
        return @bitCast(u64, self) & ALL_NOT_RESERVED;
    }

    pub fn format(value: XCr0, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        return formatWithoutFields(
            value,
            options,
            writer,
            &.{ "z_reserved8", "z_reserved10_15", "z_reserved16_47", "z_reserved48_55", "z_reserved56_61", "z_reserved63" },
        );
    }

    test {
        try std.testing.expectEqual(@as(usize, 64), @bitSizeOf(XCr0));
        try std.testing.expectEqual(@as(usize, 8), @sizeOf(XCr0));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
