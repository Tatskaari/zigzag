const std = @import("std");
const arch = @import("kernel").arch;

pub const Callback = struct {
    context: *anyopaque = undefined,
    func:  *const fn(*anyopaque) void
};


const Job = struct {
    count: usize,
    origianl_count: usize,
    callback: Callback,
    repeat: bool,
};

const JobList = std.ArrayList(Job);


pub const Timer = struct {
    jobs : JobList,

    pub fn tickOpaque(self: *anyopaque) void {
        const ticker : *Timer = @ptrCast(@alignCast(self));
        ticker.tick();
    }

    pub fn tick(self: *Timer) void {
        var i: usize = 0;
        while(i < self.jobs.items.len) {
            const job = &self.jobs.items[i];

            job.count -= 1;
            if(job.count != 0) {
                // Not our time yet. Just move on to the next item.
                i += 1;
                continue;
            }

            // We expired so call the callback
            job.callback.func(job.callback.context);
            if (!job.repeat) {
                // Remove this item from the list. Don't uncrement i, because we swapped in the last element to the current
                // index.
                _ = self.jobs.swapRemove(i);
                continue;
            }

            // Re-up on our count!
            job.count = job.origianl_count;
            i += 1;
        }
    }

    pub fn add_timer(self: *Timer, ms: usize, repeat: bool, callback: Callback) void {
        var new = self.jobs.addOne() catch @panic("failed to extend timer list");
        new.count = ms;
        new.origianl_count = ms;
        new.callback = callback;
        new.repeat = repeat;
    }

    pub fn isr(comptime self: *Timer) type {
        return struct {
            fn isr(_: arch.idt.InterruptStackFrame) void {
                self.tick();
                arch.lapic.getLapic().end();
            }
        };
    }

    pub fn deinit(self: *Timer) void {
        self.jobs.deinit();
    }

    pub fn init(alloc: std.mem.Allocator) Timer {
        return Timer{
            .jobs = JobList.init(alloc),
        };
    }
};

pub var timer : Timer = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    timer = Timer.init(alloc);
}