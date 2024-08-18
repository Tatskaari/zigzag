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

    const a : u64 = 10;

    const pt = arch.paging.getCurrentPageTable();
    const vitrt_addr : arch.paging.VirtualMemoryAddress = @bitCast(@intFromPtr(&a));

    drivers.terminal.print("virtual address: 0x{x} 0x{x} 0x{x} 0x{x}\n", .{vitrt_addr.page_map_level_4, vitrt_addr.page_dir_pointer, vitrt_addr.page_dir, vitrt_addr.page_table});
    // Get a pointer to some memeory

    // These should be the same
    const physical_address_from_pt = arch.paging.physical_from_virtual(pt, @bitCast(vitrt_addr));
    const physical_address_from_hhdm = kernel.mem.physical_from_virtual(@bitCast(vitrt_addr));

    _ = physical_address_from_hhdm;

    const a_ptr : *u64 = @ptrFromInt(kernel.mem.virtual_from_physical(physical_address_from_pt));
    a_ptr.* = 15;

    drivers.terminal.print("a {}\n", .{a});

    done();
}
