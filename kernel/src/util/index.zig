const std = @import("std");

const AttomicBool = std.atomic.Value(bool);

pub const Lock = struct {
    locked: AttomicBool,

    pub fn lock(self: *Lock) void {
        while(true) {
            const success = self.locked.cmpxchgWeak(false, true, std.builtin.AtomicOrder.acquire, std.builtin.AtomicOrder.acquire);
            if(success != null) {
                return;
            }
        }
    }

    pub fn unlock(self: *Lock) void {
        self.locked.store(false, std.builtin.AtomicOrder.release);
    }

    pub fn init() Lock {
        return Lock{
            .locked = AttomicBool.init(false),
        };
    }
};