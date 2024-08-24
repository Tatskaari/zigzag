const std = @import("std");

const kernel = @import("kernel");
const cpu = kernel.arch.cpu;

const stack_size = 16 * 1024;

const ThreadList = std.ArrayList(Thread);

const Thread = struct {
    state: State,
    ctx: cpu.Context,
    stack: []u8,
    last_executed: usize = 0,

    pub const State = enum {
        ready,
        parked, // Thread is waiting for something e.g. a timer, or an io operation
        dead,
    };

    pub fn isDead(self: *const Thread) bool {
        return self.state == State.dead;
    }

    pub fn isParked(self: *const Thread) bool {
        return self.state == State.parked;
    }
};

const Scheduler = struct {
    lock: kernel.util.Lock,

    // Is incremented every time we execute to keep track of the last execution time for a thread
    current_execution: usize = 0,
    current_thread: ?*Thread = null,

    threads: ThreadList,
    parked_threads: ThreadList,

    allocator: std.mem.Allocator,


    pub fn init(alloc: std.mem.Allocator) !Scheduler {
        return Scheduler{
            .allocator = alloc,
            .threads = ThreadList.init(alloc),
            .parked_threads = ThreadList.init(alloc),
            .lock = kernel.util.Lock.init(),
        };
    }

    /// getNextThread loops through all the threads to find the one with the lowest last executed time
    pub fn getNextThread(self: *Scheduler, ctx: cpu.Context) !*Thread {
        self.lock.lock();
        defer self.lock.unlock();

        var i : usize = 0;
        var best_thread = self.current_thread;
        while(i < self.threads.items.len) {
            var thread = self.threads.items[i];
            if (thread.isDead()) {
                _ = self.threads.swapRemove(i);
                self.allocator.free(thread.stack);
                continue;
            }

            if(thread.isParked()) {
                const parked = try self.parked_threads.addOne();
                parked.* = thread;
                _ = self.threads.swapRemove(i);
                continue;
            }

            if(best_thread == null or thread.last_executed < best_thread.?.last_executed) {
                best_thread = &thread;
            }

            i += 1;
        }

        // The first time around the current thread will not be the context we received.
        // TODO we should pass control over to the context using iret so this isn't true
        if (self.current_thread != null) {
            self.current_thread.?.last_executed = self.current_execution;
            self.current_thread.?.ctx = ctx;
        }


        self.current_execution += 1;
        self.current_thread = best_thread;

        return best_thread.?;
    }

    pub fn fork(self: *Scheduler, ctx: cpu.Context, func: *const anyopaque) !*Thread {
        self.lock.lock();
        defer self.lock.unlock();

        const stack = try self.allocator.alloc(u8, stack_size);
        const thread = try self.threads.addOne();
        thread.* = Thread{
            .state = Thread.State.ready,
            .stack = stack,
            .ctx = ctx,
        };

        thread.ctx.rip = @intFromPtr(func);
        thread.ctx.rbp = @intFromPtr(stack.ptr);
        thread.ctx.rsp = thread.ctx.rbp;
        return thread;
    }

    pub fn start(_: *Scheduler) noreturn {
        // TODO this is where we should pass off execution to the current thread (which shouldn't be nullable)
        kernel.arch.lapic.getLapic().setTimerNs(quanta);
        while (true) {
            asm volatile ("hlt");
        }
    }
};

// The period of time between each context switch
const quanta = 1000 * 1000; // 20ms
pub var scheduler : Scheduler = undefined;

fn isr(ctx: *cpu.Context) callconv(.C) void {
    const thread = scheduler.getNextThread(ctx.*) catch @panic("Scheduler error: failed to get next thread");
    ctx.* = thread.ctx;
    kernel.arch.lapic.getLapic().end();
    kernel.arch.lapic.getLapic().setTimerNs(quanta);
}

pub fn init(alloc: std.mem.Allocator, initial: *const anyopaque) void {
    const ctx = cpu.Context{
        .cs = cpu.getCS(), // TODO this should enter into userspace and use their segment select
        .ss = cpu.getSS(),
        .rflags =  0x200, // TODO this sets interrupt enable but it's a bit jank.
    };
    scheduler = Scheduler.init(alloc) catch @panic("failed to init scheduler");
    _ = scheduler.fork(ctx, initial) catch @panic("failed to fork initial thread");

    const vec = kernel.arch.idt.registerInterrupt(isr, 0);
    kernel.arch.lapic.getLapic().setTimerIsr(vec, kernel.arch.lapic.APIC.TimerVec.Mode.one_shot);
}
