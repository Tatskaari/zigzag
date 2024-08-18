const limine = @import("limine");
const std = @import("std");
const arch = @import("arch");
const drivers = @import("drivers");
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

// TODO this should panic over serial until we have set up the terminal
pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    drivers.terminal.print("{s}", .{message});
    done();
}

// The following will be our kernel's entry point.
export fn _start() callconv(.C) noreturn {
    kernel.mem.init();
    drivers.terminal.init(kernel.mem.allocator);

    // Ensure the bootloader actually understands our base revision (see spec).
    if (!base_revision.is_supported()) {
        @panic("boot error: limine bootloader base revision not supported");
    }

    arch.rsdt.init();
    arch.init();

    arch.interupts.enable();
    drivers.init();

    arch.pci.lspci();
    // arch.paging.init();

    const physical_add = arch.cpu.cr3.read();
    const virt_add = kernel.mem.virtual_from_physical(physical_add);

    // These should be the same
    const physical_address_from_pt = arch.paging.physical_from_virtual(arch.paging.get_current_page_table(), virt_add);
    const physical_address_from_hhdm = kernel.mem.physical_from_virtual(virt_add);

    drivers.terminal.print("original {x} from hhdm {x} from page tables {x}", .{physical_add, physical_address_from_hhdm, physical_address_from_pt});

    done();
}
