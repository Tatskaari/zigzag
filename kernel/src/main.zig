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
    if(!kernel.drivers.terminal.initialised) {
        kernel.drivers.serial.COM1.writer().print("fatal error: {s}\n", .{message}) catch unreachable;
    } else {
        kernel.drivers.terminal.print("fatal error: {s}\n", .{message});
    }
    done();
}

// The following will be our kernel's entry point.
export fn _start() callconv(.C) noreturn {
    kernel.arch.interupts.init();
    kernel.drivers.serial.init();
    kernel.services.mem.init();
    kernel.drivers.terminal.init(std.heap.page_allocator);

    // Ensure the bootloader actually understands our base revision (see spec).
    if (!base_revision.is_supported()) {
        @panic("boot error: limine bootloader base revision not supported");
    }

    kernel.arch.rsdt.init();
    kernel.arch.init();

    kernel.arch.interupts.enable();
    kernel.drivers.init();

    kernel.arch.pci.lspci();

    const physical_add = kernel.arch.cpu.cr3.read();
    const virt_add = kernel.services.mem.hhdm.virtualFromPhysical(physical_add);

    // These should be the same
    const physical_address_from_pt = kernel.arch.paging.getCurrentPageTable().physicalFromVirtual(virt_add).?;
    const physical_address_from_hhdm = kernel.services.mem.hhdm.physicalFromVirtual(virt_add);

    kernel.drivers.terminal.print("original {x} from hhdm {x} from page tables {x}\n", .{physical_add, physical_address_from_hhdm, physical_address_from_pt});

    // Create a virtual address
    const virtual_address = kernel.arch.paging.VirtualMemoryAddress{
        .offset = 0,
        .page_map_level_4 = 0x10,
        .page_dir_pointer = 0x10,
        .page_dir = 0x10,
        .page_table = 0x10,
        .sign = 0,
    };
    // Create a page
    const page = kernel.services.mem.PageMap.alloc() catch unreachable;
    const page_physical_address = page << 12; // The page is aligned to 4k, so we shift it left to get it's actual address
    // Create a new mapping from a virtual address to this page
    kernel.arch.paging.getCurrentPageTable().map(
        @bitCast(virtual_address),
        page_physical_address,
        .{
            .no_exec = false,
            .user = false,
            .writable = true,
        },
    ) catch unreachable;

    const buf = std.heap.page_allocator.alloc(u8, 100) catch unreachable;
    std.heap.page_allocator.free(buf);

    // Write to our virtual address
    const a: *usize = @ptrFromInt(virtual_address.to_usize());
    a.* = 10;

    // Check that the direct mapping reads the value we just got
    const b: *usize = @ptrFromInt(kernel.services.mem.hhdm.virtualFromPhysical(page_physical_address));
    kernel.drivers.terminal.print("should be 10: {}\n", .{b.*});
    b.* = 11;
    kernel.drivers.terminal.print("should be 11: {}\n", .{a.*});

    done();
}
