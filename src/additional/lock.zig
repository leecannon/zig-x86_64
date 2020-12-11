usingnamespace @import("../common.zig");

/// A spinlock that disables interrupts (if they are enabled) when the lock is taken
/// and enables them again when it is released if they were previously enabled.
pub const KernelSpinLock = struct {
    const Self = @This();

    state: State,

    const State = enum(u8) {
        Unlocked,
        Locked,
    };

    pub const Held = struct {
        interrupts_enabled: bool,
        spinlock: *Self,

        pub fn release(self: Held) void {
            @atomicStore(State, &self.lock.locked, .Unlocked, .Release);
            if (self.interrupts_enabled) instructions.interrupts.enable();
        }
    };

    pub inline fn init() Self {
        return .{ .state = .Unlocked };
    }

    pub fn tryAcquire(self: *Self) ?Held {
        const interrupts_enabled = instructions.interrupts.areEnabled();

        if (interrupts_enabled) instructions.interrupts.disable();

        switch (@atomicRmw(State, &self.state, .Xchg, .Locked, .Acquire)) {
            .Unlocked => {
                return Held{
                    .interrupts_enabled = interrupts_enabled,
                    .spinlock = self,
                };
            },
            .Locked => {
                if (interrupts_enabled) instructions.interrupts.enable();
                return null;
            },
        }
    }

    pub fn acquire(self: *Self) Held {
        while (true) {
            return self.tryAcquire() orelse {
                instructions.pause();
                continue;
            };
        }
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

pub const KernelSpinLockNoDisableInterrupts = struct {
    const Self = @This();

    state: State,

    const State = enum(u8) {
        Unlocked,
        Locked,
    };

    pub const Held = struct {
        spinlock: *Self,

        pub inline fn release(self: Held) void {
            @atomicStore(State, &self.lock.locked, .Unlocked, .Release);
        }
    };

    pub inline fn init() Self {
        return .{ .state = .Unlocked };
    }

    pub fn tryAcquire(self: *Self) ?Held {
        return switch (@atomicRmw(State, &self.state, .Xchg, .Locked, .Acquire)) {
            .Unlocked => Held{ .spinlock = self },
            .Locked => null,
        };
    }

    pub fn acquire(self: *Self) Held {
        while (true) {
            return self.tryAcquire() orelse {
                instructions.pause();
                continue;
            };
        }
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "" {
    std.testing.refAllDecls(@This());
}
