pub usingnamespace @import("addr.zig");

pub const cpuid = @import("cpuid.zig");

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

    pub fn fromU16(value: u16) PrivilegeLevelError!PrivilegeLevel {
        return switch (value) {
            0 => PrivilegeLevel.Ring0,
            1 => PrivilegeLevel.Ring1,
            2 => PrivilegeLevel.Ring2,
            3 => PrivilegeLevel.Ring3,
            else => error.InvalidPrivledgeLevel,
        };
    }

    pub fn toU16(self: PrivilegeLevel) u16 {
        return @enumToInt(self);
    }
};

test "" {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
