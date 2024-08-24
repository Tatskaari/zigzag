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
    kernel.debug.print("panic: .{s}\n", .{message});
    done();
}

fn timerPrint(_ : *const anyopaque) void {
    kernel.debug.print("timer!", .{});
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
}


pub fn lapicIsr(_: *kernel.arch.cpu.Context) callconv(.C) void {
    kernel.debug.print("got lapic timer\n", .{});
    kernel.arch.lapic.get_lapic().end();
}

// The following will be our kernel's entry point.
export fn _start() callconv(.C) noreturn {
    stage1();
    kernel.arch.pci.lspci();
    kernel.services.timer.timer.add_timer(2000, false, .{
        .func = timerPrint,
        .context = undefined,
    });

    const vec = kernel.arch.idt.registerInterrupt(&lapicIsr, 0);

    kernel.arch.lapic.get_lapic().setTimerIsr(vec, kernel.arch.lapic.APIC.TimerVec.Mode.one_shot);
    kernel.arch.lapic.get_lapic().setTimerNs(1000*1000); // 1000*1000 == 1 second
    done();
}
