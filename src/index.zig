pub usingnamespace @import("addr.zig");

pub const structures = @import("structures/structures.zig");

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
    
    pub fn from_u16(value: u16) PrivilegeLevel {       
        return switch (value) {
            0 => PrivilegeLevel.Ring0,
            1 => PrivilegeLevel.Ring1,
            2 => PrivilegeLevel.Ring2,
            3 => PrivilegeLevel.Ring3,
            else => @panic("{} is not a valid privilege level", .{value})
        };
    }
};

test "" {
    // Test non-public files
    const bits = @import("bits.zig");
}
