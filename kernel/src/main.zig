const limine = @import("limine");
const std = @import("std");
const drivers = @import("drivers");
const kernel = @import("kernel");

const interrupts = @import("interrupts.zig");

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
    drivers.terminal.print("{s}", .{message});
    done();
}

// The following will be our kernel's entry point.
export fn _start() callconv(.C) noreturn {
    interrupts.init();
    kernel.mem.init();

    // Ensure the bootloader actually understands our base revision (see spec).
    if (!base_revision.is_supported()) {
        done();
    }

    drivers.terminal.init() catch {
        done();
    };

    drivers.pci.lspci();

    drivers.terminal.print("This should come before {}\n", .{10});
    asm volatile ("int $0x10");
    drivers.terminal.print("This should come after {}\n", .{10});

    drivers.rsdt.init() catch unreachable;


    // We're done, just hang...
    @panic("test panic");
}
