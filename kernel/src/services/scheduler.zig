const std = @import("std");

const kernel = @import("kernel");
const cpu = kernel.arch.cpu;

const stack_size = 16 * 1024;

// 0x200 sets the 9th bit which is the interupt flag. 0x2 sets some legacy flag.
const rflag_interrupt_enabled = 0x202;

const ThreadList = std.ArrayList(Thread);

const Thread = struct {
    id: usize,
    state: State,
    ctx: cpu.Context,
    stack: []u8,
    enqueued_time: usize = 0, // When the thread last became ready

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

    inline fn restoreRegister(comptime name: []const u8, value: u64) void {
        asm volatile (std.fmt.comptimePrint("mov %{s}, %[value]", .{name}) :: [value] "r" (value) : "memory");
    }

    /// run will restore the current thread state and continue execution
    pub fn run(self: *const Thread) noreturn {
        const ctx = self.ctx;

        // Restore the cpu registers that are not handled by iret
        restoreRegister("es", ctx.es);
        restoreRegister("ds", ctx.ds);
        restoreRegister("r15", ctx.r15);
        restoreRegister("r14", ctx.r14);
        restoreRegister("r13", ctx.r13);
        restoreRegister("r12", ctx.r12);
        restoreRegister("r11", ctx.r11);
        restoreRegister("r10", ctx.r10);
        restoreRegister("r9", ctx.r9);
        restoreRegister("r8", ctx.r8);
        restoreRegister("rsi", ctx.rsi);
        restoreRegister("rdi", ctx.rdi);
        restoreRegister("rdx", ctx.rdx);
        restoreRegister("rcx", ctx.rcx);
        restoreRegister("rbx", ctx.rbx);
        restoreRegister("rax", ctx.rax);
        restoreRegister("rbp", ctx.rbp);

        // Set up the iret frame and return
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

const Scheduler = struct {
    lock: kernel.util.Lock,

    next_id: usize = 1,

    // Is incremented every time we execute to keep track of the last execution time for a thread, in place of a propper
    // timestamp
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
            .lock = kernel.util.Lock.init(),
        };
    }

    /// getNextThread loops through all the threads to find the one with the lowest last executed time
    pub fn getNextThread(self: *Scheduler, ctx: cpu.Context) !*Thread {
        self.lock.lock();
        defer self.lock.unlock();

        var i: usize = 0;
        var best_thread: ?*Thread = null;
        while (i < self.threads.items.len) {
            var thread = &self.threads.items[i];

            // Update the current thread with the new context and execution time
            if (thread.id == self.current_thread_id) {
                // Add the thread back into the queue with this current time
                thread.enqueued_time = self.current_execution;
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

            if (best_thread == null or thread.enqueued_time < best_thread.?.enqueued_time) {
                best_thread = thread;
            }

            i += 1;
        }

        self.current_execution += 1;
        self.current_thread_id = best_thread.?.id;

        return best_thread.?;
    }

    pub fn fork(self: *Scheduler, ctx: cpu.Context, func: *const anyopaque) !void {
        self.lock.lock();
        defer self.lock.unlock();

        const stack = try self.allocator.alloc(u8, stack_size);
        const thread = try self.threads.addOne();
        thread.* = Thread{
            .state = Thread.State.ready,
            .stack = stack,
            .ctx = ctx,
            .id = self.next_id,
        };

        self.next_id += 1;

        thread.ctx.rip = @intFromPtr(func);
        thread.ctx.rbp = @intFromPtr(stack.ptr);
        thread.ctx.rsp = thread.ctx.rbp;
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
        self.findCurrentThread().run();
    }
};

// The period of time between each context switch
const quanta = 100 * 1000; // 100ms
pub var scheduler: Scheduler = undefined;

export fn isr(ctx: *cpu.Context) callconv(.C) noreturn {
    const thread = scheduler.getNextThread(ctx.*) catch @panic("Scheduler error: failed to get next thread");
    kernel.arch.lapic.getLapic().end();
    kernel.arch.lapic.getLapic().setTimerNs(quanta);
    thread.run();
}

pub fn newUserspaceContext() cpu.Context {
    return cpu.Context{
        .cs = cpu.getCS(), // TODO this should enter into userspace and use their segment select
        .ss = cpu.getSS(),
        .rflags = rflag_interrupt_enabled, // Sets the interrupt flag and some legacy
    };
}

// wrapCall will wrap the interrupt in C calling convention in a naked function that pushes the CPU context to the stack
//
// This code is heavily inspired (stolen?) by the wrapper here:
// https://github.com/yhyadev/yos/blob/master/src/kernel/arch/x86_64/cpu.zig#L192
pub fn wrapCall(comptime func: fn (ctx: *cpu.Context) callconv(.C) void) *const anyopaque {
    const closure = struct {
        pub fn wrapper() callconv(.Naked) noreturn {
            asm volatile (
                // Push the CPU state to the stack in reverse order to how they're defined in cpu.Context
                \\ push %rbp
                \\ push %rax
                \\ push %rbx
                \\ push %rcx
                \\ push %rdx
                \\ push %rdi
                \\ push %rsi
                \\ push %r8
                \\ push %r9
                \\ push %r10
                \\ push %r11
                \\ push %r12
                \\ push %r13
                \\ push %r14
                \\ push %r15
                \\ mov %ds, %rax
                \\ push %rax
                \\ mov %es, %rax
                \\ push %rax
                \\ mov $0x10, %ax
                \\ mov %ax, %ds
                \\ mov %ax, %es
                \\ cld
            );

            // Put a pointer to the above context on the stack frame and call the function
            asm volatile (
                \\ mov %rsp, %rdi
                \\ call *%[isr]
                :
                : [isr] "{rax}" (func),
            );
            // The isr should run the thread for us.
        }
    };
    return &closure.wrapper;
}

pub fn init(alloc: std.mem.Allocator, initial: *const anyopaque) void {
    scheduler = Scheduler.init(alloc) catch @panic("failed to init scheduler");
    scheduler.fork(newUserspaceContext(), initial) catch @panic("failed to fork initial thread");

    const vec = kernel.arch.idt.getVector();
    kernel.arch.idt.setDescriptor(vec, wrapCall(isr), 0, kernel.arch.idt.IDTEntry.Kind.interrupt);
    kernel.arch.lapic.getLapic().setTimerIsr(vec, kernel.arch.lapic.APIC.TimerVec.Mode.one_shot);
}
