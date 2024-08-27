const std = @import("std");


/// Lock implements a simple lock, without any special help from the system. This is a spin lock.
pub const Lock = struct {
    locked: std.atomic.Value(bool) = .{.raw = false},

    pub fn lock(self: *Lock) void {
        while(true) {
            const value = self.locked.cmpxchgWeak(false, true, std.builtin.AtomicOrder.acquire, std.builtin.AtomicOrder.acquire);
            if(value == null) {
                return;
            }
        }
    }

    pub fn unlock(self: *Lock) void {
        self.locked.store(false, std.builtin.AtomicOrder.release);
    }
};