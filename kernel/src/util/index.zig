const std = @import("std");

const AttomicBool = std.atomic.Value(bool);

pub const Lock = struct {
    locked: AttomicBool = .{.raw = false},

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