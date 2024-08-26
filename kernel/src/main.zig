const limine = @import("limine");
const std = @import("std");

pub const os = @import("os.zig");

const kernel = @import("kernel");

// Set the base revision to 2, this is recommended as this is the latest
// base revision described by the Limine boot protocol specification.
// See specification for further info.
pub export var base_revision: limine.BaseRevision = .{ .revision = 2 };

inline fn done() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    kernel.debug.print("panic: {s}\n", .{message});
    done();
}

fn timerPrint(_: *const anyopaque) void {
    kernel.debug.print("timer!\n", .{});
}

/// stage1 initialises the CPU, gets interrupts working, and debug logging
pub fn stage1() void {
    kernel.drivers.serial.init(); // debug logging to serial works at this point
    kernel.arch.interupts.init(); // now exceptions are handled

    kernel.services.mem.init(); // now we can allocate memory
    kernel.drivers.terminal.init(std.heap.page_allocator); // now logging happens to the terminal

    // Ensure the bootloader actually understands our base revision (see spec).
    if (!base_revision.is_supported()) {
        @panic("boot error: limine bootloader base revision not supported");
    }

    // Get local interrupts enabled
    kernel.arch.pic.disable();
    kernel.arch.lapic.init();
    kernel.arch.interupts.enable();

    // Now get the io apic information from the system descriptor tables
    const rsdt = kernel.arch.rsdt.getRsdt();
    const madt = kernel.arch.madt.getMadt(rsdt);
    const ioapic = kernel.arch.ioapic.getIoApic(madt);

    kernel.services.timer.init(std.heap.page_allocator);
    // Get the PIT and keyboard interrupts set up
    kernel.arch.pit.init(&ioapic, .{
        .context = &kernel.services.timer.timer,
        .func = kernel.services.timer.Timer.tickOpaque,
    });

    kernel.arch.lapic.calibrate(&kernel.services.timer.timer);
    kernel.drivers.keyboard.init(&ioapic);

    kernel.services.scheduler.init(std.heap.page_allocator, &main);
}

fn main() noreturn {
    var i: usize = 0;
    while (true) {
        for (0..50000000) |_| {} // Just a delay because we don't have sleep yet
        kernel.debug.print("main: got scheduled! {}\n", .{i});
        i += 1;
    }
    done();
}

fn main2() noreturn {
    var i: usize = 0;
    while (true) {
        for (0..50000000) |_| {} // Just a delay because we don't have sleep yet
        kernel.debug.print("main 2: got scheduled! {}\n", .{i});
        i += 1;
    }
    done();
}

// The following will be our kernel's entry point.
export fn _start() callconv(.C) noreturn {
    stage1();
    // kernel.arch.pci.lspci();
    kernel.services.timer.timer.add_timer(2000, false, .{
        .func = timerPrint,
        .context = undefined,
    });
    const sched = kernel.services.scheduler;
    _ = sched.scheduler.fork(sched.newContext(), &main2) catch @panic("wahhhh");

    // Passes off control to the main thread above.
    kernel.services.scheduler.scheduler.start();
}
