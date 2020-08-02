usingnamespace @import("../common.zig");

/// A spinlock that disables interrupts (if they are enabled) when the lock is taken
/// and enables them again when it is released if they were previously enabled.
/// ### Remarks:
/// If the lock is not acquired immediately then a weak spin on the lock bit occurs with interrupts enabled
pub const SpinLock = struct {
    locked: bool,

    /// A token representing a locked lock
    pub const LockToken = struct {
        /// Were interrupts enabled prior to the lock being acquired
        interrupts_enabled: bool,
        lock: *SpinLock,

        // Unlocks the lock
        pub inline fn unlock(self: *const LockToken) void {
            self.lock.locked = false;
            if (self.interrupts_enabled) instructions.interrupts.enable();
        }
    };

    /// Create a new SpinLock
    pub fn init() SpinLock {
        return SpinLock{ .locked = false };
    }

    /// Acquire the lock.
    /// Interrupts are disabled while the lock is held and re-enabled upon release if previously enabled.
    /// If the lock is not acquired immediately then a weak spin on the lock bit occurs with interrupts enabled
    pub fn lock(self: *SpinLock) LockToken {
        const interrupts_enabled = instructions.interrupts.are_enabled();

        if (interrupts_enabled) instructions.interrupts.disable();

        while (@cmpxchgStrong(bool, &self.locked, false, true, std.builtin.AtomicOrder.SeqCst, std.builtin.AtomicOrder.SeqCst) != null) {
            instructions.interrupts.enable();

            spin_pause();
            while (self.locked) {
                spin_pause();
            }

            instructions.interrupts.disable();
        }

        return LockToken{
            .interrupts_enabled = interrupts_enabled,
            .lock = self,
        };
    }

    /// Try to acquire the lock, returns a LockToken if acquired null otherwise
    /// Interrupts are disabled while the lock is held and re-enabled upon release if previously enabled.
    pub fn try_lock(self: *SpinLock) ?LockToken {
        const interrupts_enabled = instructions.interrupts.are_enabled();

        if (interrupts_enabled) instructions.interrupts.disable();

        if (@cmpxchgStrong(bool, &self.locked, false, true, std.builtin.AtomicOrder.SeqCst, std.builtin.AtomicOrder.SeqCst) == null) {
            return LockToken{
                .interrupts_enabled = interrupts_enabled,
                .lock = self,
            };
        }

        if (interrupts_enabled) instructions.interrupts.enable();
        return null;
    }
};

/// A spinlock that does *NOT* disable interrupts.
/// ### Warning:
/// It is easy to deadlock with this type of lock. If a interrupt occurs while the lock is held and the interrupt handler in some way tries to acquire the lock then a deadlock will occur.
/// This lock should only be used if the core/cpu acquiring the lock is guarenteed not to attempt to re-acquire while it is still held.
pub const UnsafeSpinLock = struct {
    locked: bool,

    /// A token representing a locked lock
    pub const LockToken = struct {
        lock: *UnsafeSpinLock,

        // Unlocks the lock
        pub inline fn unlock(self: *const LockToken) void {
            self.lock.locked = false;
        }
    };

    /// Create a new SpinLock
    pub fn init() UnsafeSpinLock {
        return UnsafeSpinLock{ .locked = false };
    }

    /// Acquire the lock.
    /// If the lock is not acquired immediately then a weak spin on the lock bit occurs
    pub fn lock(self: *UnsafeSpinLock) LockToken {
        while (@cmpxchgStrong(bool, &self.locked, false, true, std.builtin.AtomicOrder.SeqCst, std.builtin.AtomicOrder.SeqCst) != null) {
            spin_pause();
            while (self.locked) {
                spin_pause();
            }
        }

        return LockToken{
            .lock = self,
        };
    }

    /// Try to acquire the lock, returns a LockToken if acquired null otherwise
    pub fn try_lock(self: *UnsafeSpinLock) ?LockToken {
        if (@cmpxchgStrong(bool, &self.locked, false, true, std.builtin.AtomicOrder.SeqCst, std.builtin.AtomicOrder.SeqCst) == null) {
            return LockToken{
                .lock = self,
            };
        }

        return null;
    }
};

inline fn spin_pause() void {
    asm volatile ("pause");
}

test "" {
    std.meta.refAllDecls(@This());
}
