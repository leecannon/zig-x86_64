usingnamespace @import("../common.zig");

const State = enum(u8) {
    Unlocked,
    Locked,
};

/// A spinlock that disables interrupts (if they are enabled) when the lock is taken
/// and enables them again when it is released if they were previously enabled.
/// ### Remarks:
/// If the lock is not acquired immediately then a weak spin on the lock bit occurs with interrupts enabled
pub const KernelSpinLock = struct {
    state: State,

    /// A token representing a locked lock
    pub const LockToken = struct {
        /// Were interrupts enabled prior to the lock being acquired
        interrupts_enabled: bool,
        lock: *KernelSpinLock,

        // Unlocks the lock
        pub inline fn unlock(self: *const LockToken) void {
            @atomicStore(State, &self.lock.state, .Unlocked, .Release);
            if (self.interrupts_enabled) instructions.interrupts.enable();
        }
    };

    /// Create a new SpinLock
    pub fn init() KernelSpinLock {
        return KernelSpinLock{ .state = .Unlocked };
    }

    /// Try to acquire the lock, returns a LockToken if acquired null otherwise
    /// Interrupts are disabled while the lock is held and re-enabled upon release if previously enabled.
    pub fn try_lock(self: *KernelSpinLock) ?LockToken {
        const interrupts_enabled = instructions.interrupts.are_enabled();

        if (interrupts_enabled) instructions.interrupts.disable();

        switch (@atomicRmw(State, &self.state, .Xchg, .Locked, .Acquire)) {
            .Unlocked => return LockToken{
                .interrupts_enabled = interrupts_enabled,
                .lock = self,
            },
            .Locked => {
                if (interrupts_enabled) instructions.interrupts.enable();
                return null;
            },
        }
    }

    /// Acquire the lock.
    /// Interrupts are disabled while the lock is held and re-enabled upon release if previously enabled.
    /// If the lock is not acquired immediately then a weak spin on the lock bit occurs with interrupts enabled
    pub fn lock(self: *KernelSpinLock) LockToken {
        const interrupts_enabled = instructions.interrupts.are_enabled();

        if (interrupts_enabled) instructions.interrupts.disable();

        while (true) {
            if (@atomicRmw(State, &self.state, .Xchg, .Locked, .Acquire) == .Unlocked) {
                return LockToken{
                    .interrupts_enabled = interrupts_enabled,
                    .lock = self,
                };
            }

            if (interrupts_enabled) instructions.interrupts.enable();

            spin_pause();
            while (self.state == .Locked) {
                spin_pause();
            }

            if (interrupts_enabled) instructions.interrupts.disable();
        }
    }
};

inline fn spin_pause() void {
    asm volatile ("pause"
        :
        :
        : "memory"
    );
}

test "" {
    std.testing.refAllDecls(@This());
}
