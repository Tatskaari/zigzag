const std = @import("std");

const kernel = @import("kernel");
const cpu = kernel.arch.cpu;
const gdt = kernel.arch.gdt;
const paging = kernel.arch.paging;
const mem = kernel.services.mem;
const rflag_default = 0x202; // Interrupt enable and some legacy flag

// 8mb stacks
const stack_size = 8 * 1024 * 1024;

const ThreadList = std.ArrayList(Thread);

const Thread = struct {
    id: usize,
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

// TODO this isn't fair at all and will randomly schedule the same thread twice if there's no tiebreaker
const Scheduler = struct {
    next_id: usize = 1,

    // Is incremented every time we execute to keep track of the last execution time for a thread
    current_execution: usize = 1,
    current_thread_id: usize = 1,

    threads: ThreadList,
    parked_threads: ThreadList,

    allocator: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !Scheduler {
        return Scheduler{
            .allocator = alloc,
            .threads = ThreadList.init(alloc),
            .parked_threads = ThreadList.init(alloc),
        };
    }

    /// getNextThread loops through all the threads to find the one with the lowest last executed time
    pub fn getNextThread(self: *Scheduler, ctx: cpu.Context) !*Thread {
        var i: usize = 0;
        var best_thread: ?*Thread = null;
        while (i < self.threads.items.len) {
            var thread = &self.threads.items[i];

            // Update the current thread with the new context and execution time
            if (thread.id == self.current_thread_id) {
                thread.last_executed = self.current_execution;
                thread.ctx = ctx;
            }

            if (thread.isDead()) {
                _ = self.threads.swapRemove(i);
                self.allocator.free(thread.stack);
                continue;
            }

            if (thread.isParked()) {
                const parked = try self.parked_threads.addOne();
                parked.* = thread.*;
                _ = self.threads.swapRemove(i);
                continue;
            }

            if (best_thread == null or thread.last_executed < best_thread.?.last_executed) {
                best_thread = thread;
            }

            i += 1;
        }

        self.current_execution += 1;
        self.current_thread_id = best_thread.?.id;

        return best_thread.?;
    }

    pub fn fork(self: *Scheduler, user: bool, func: *const anyopaque) !void {
        const stack = try self.allocator.alloc(u8, stack_size);
        const thread = try self.threads.addOne();
        thread.* = Thread{
            .state = Thread.State.ready,
            .stack = stack,
            .ctx = newContext(user),
            .id = self.next_id,
        };

        self.next_id += 1;

        thread.ctx.rip = @intFromPtr(func);
        // The stack grows down
        thread.ctx.rbp = @intFromPtr(stack.ptr) + stack.len;
        thread.ctx.rsp = @intFromPtr(stack.ptr) + stack.len;
    }

    pub fn findCurrentThread(self: *Scheduler) *const Thread {
        for (self.threads.items) |t| {
            if (t.id == self.current_thread_id) {
                return &t;
            }
        }
        unreachable;
    }

    pub fn start(self: *Scheduler) noreturn {
        // Start the interupt timer to trigger the scheduler
        kernel.arch.lapic.getLapic().setTimerNs(quanta);

        // Push the iret frame to the stack and call iret
        // TODO do we clean up the kernel's stack?
        const ctx = self.findCurrentThread().ctx;
        asm volatile (
            \\ push %[ss]
            \\ push %[rsp]
            \\ push %[rflags]
            \\ push %[cs]
            \\ push %[rip]
            \\ iretq
            :
            : [rip] "r" (ctx.rip),
              [cs] "r" (ctx.cs),
              [rflags] "r" (ctx.rflags),
              [rsp] "r" (ctx.rsp),
              [ss] "r" (ctx.ss),
            : "memory"
        );
        unreachable;
    }
};

// The period of time between each context switch
const quanta = 20 * 1000; // 100ms
pub var scheduler: Scheduler = undefined;

fn isr(ctx: *cpu.Context) callconv(.C) void {
    const thread = scheduler.getNextThread(ctx.*) catch @panic("Scheduler error: failed to get next thread");
    ctx.* = thread.ctx;
    kernel.arch.lapic.getLapic().end();
    kernel.arch.lapic.getLapic().setTimerNs(quanta);
}

pub fn newContext(user: bool) cpu.Context {
    if (user) {
        return cpu.Context{
            .cs = gdt.user_cs,
            .ss = gdt.user_ds,
            .rflags = rflag_default,
        };
    }
    return cpu.Context{
        .cs = gdt.kernel_cs,
        .ss = gdt.kernel_ds,
        .rflags = rflag_default,
    };
}

pub fn init(alloc: std.mem.Allocator, initial: *const anyopaque) void {
    scheduler = Scheduler.init(alloc) catch @panic("failed to init scheduler");
    scheduler.fork(false, initial) catch @panic("failed to fork initial thread");

    const vec = kernel.arch.idt.registerInterrupt(isr, 0);
    kernel.arch.lapic.getLapic().setTimerIsr(vec, kernel.arch.lapic.APIC.TimerVec.Mode.one_shot);
}
