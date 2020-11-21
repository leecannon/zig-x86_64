usingnamespace @import("../common.zig");

/// A spinlock that disables interrupts (if they are enabled) when the lock is taken
/// and enables them again when it is released if they were previously enabled.
/// ### Remarks:
/// If the lock is not acquired immediately then a weak spin on the lock bit occurs with interrupts enabled
pub const KernelSpinLock = struct {
    locked: bool,

    /// A token representing a locked lock
    pub const LockToken = struct {
        /// Were interrupts enabled prior to the lock being acquired
        interrupts_enabled: bool,
        lock: *KernelSpinLock,

        // Unlocks the lock
        pub inline fn unlock(self: *const LockToken) void {
            @atomicStore(bool, &self.lock.locked, false, .Release);
            if (self.interrupts_enabled) instructions.interrupts.enable();
        }
    };

    /// Create a new SpinLock
    pub fn init() KernelSpinLock {
        return KernelSpinLock{ .locked = false };
    }

    /// Try to acquire the lock, returns a LockToken if acquired null otherwise
    /// Interrupts are disabled while the lock is held and re-enabled upon release if previously enabled.
    pub fn try_lock(self: *KernelSpinLock) ?LockToken {
        const interrupts_enabled = instructions.interrupts.are_enabled();

        if (interrupts_enabled) instructions.interrupts.disable();

        if (@cmpxchgWeak(bool, &self.locked, false, true, .Acquire, .Acquire) == null) {
            return LockToken{
                .interrupts_enabled = interrupts_enabled,
                .lock = self,
            };
        }

        if (interrupts_enabled) instructions.interrupts.enable();
        return null;
    }

    /// Acquire the lock.
    /// Interrupts are disabled while the lock is held and re-enabled upon release if previously enabled.
    /// If the lock is not acquired immediately then a weak spin on the lock bit occurs with interrupts enabled
    pub fn lock(self: *KernelSpinLock) LockToken {
        const interrupts_enabled = instructions.interrupts.are_enabled();

        if (interrupts_enabled) instructions.interrupts.disable();

        while (true) {
            if (@cmpxchgWeak(bool, &self.locked, false, true, .Acquire, .Acquire) == null) {
                return LockToken{
                    .interrupts_enabled = interrupts_enabled,
                    .lock = self,
                };
            }

            if (interrupts_enabled) instructions.interrupts.enable();

            instructions.pause();
            while (self.locked) {
                instructions.pause();
            }

            if (interrupts_enabled) instructions.interrupts.disable();
        }
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "" {
    std.testing.refAllDecls(@This());
}
