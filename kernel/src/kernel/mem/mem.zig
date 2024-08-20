const std = @import("std");
const limine = @import("limine");
const arch = @import("arch");

pub const PageMap = @import("PageMap.zig");
pub const PageAllocator = @import("PageAllocator.zig");

pub const MMapError = error{OutOfMemory};

// Limine boots with virutal memory mapping. This is done through a direct mapping, where we have an offset we can apply
// to translate between virtual and physical memory.
//
// See: https://github.com/limine-bootloader/limine/blob/v8.x/PROTOCOL.md#entry-memory-layout
export var hhdm_request: limine.HhdmRequest = .{};

// We need this to find a region on memory that we can alloc in
pub export var mem_map_request = limine.MemoryMapRequest{};

// higher_half_direct_map_offset is the offset used to map from the higher half virutal memory to physical memory
var hhdm_offset: u64 = undefined;

pub inline fn virtual_from_physical(physical: usize) usize {
    return physical + hhdm_offset;
}

pub inline fn physical_from_virtual(virtual: usize) usize {
    return virtual - hhdm_offset;
}

pub const PROT = struct {
    /// page can not be accessed
    pub const NONE = 0x0;
    /// page can be read
    pub const READ = 0x1;
    /// page can be written
    pub const WRITE = 0x2;
    /// page can be executed
    pub const EXEC = 0x4;
    /// page may be used for atomic ops
    pub const SEM = 0x8;
    /// mprotect flag: extend change to start of growsdown vma
    pub const GROWSDOWN = 0x01000000;
    /// mprotect flag: extend change to end of growsup vma
    pub const GROWSUP = 0x02000000;
};


// TODO apparently this guy does stuff with files? I guess we need to map memory to a file descriptor once we have a
// filesystem
pub fn mmap(
    ptr: ?[*]align(arch.paging.page_alignment) u8,
    length: usize,
    prot: u32,
) std.mem.Allocator.Error![]align(arch.paging.page_alignment) u8 {
    const pt = arch.paging.get_current_page_table();
    const pages_needed = @divExact(length, arch.paging.page_alignment);

    const start_address = get_next_address(pt, ptr, @divExact(length, arch.paging.page_alignment));
    var address = start_address;
    for (0..pages_needed) |_| {
        const page = try PageMap.alloc();
        // TODO check if the calling process is the kernel when we finally have usespace
        try pt.map(address, arch.paging.page_address(page), arch.paging.MapOptions{
            .no_exec = (prot & PROT.EXEC == 0),
            .writable = prot & PROT.WRITE != 0,
            .user = false,
        });
        address = address + arch.paging.page_alignment;
    }
    const ret: [*]u8 = @ptrFromInt(start_address);
    return @alignCast(ret[0..length]);
}

fn get_next_address(pt: *arch.paging.RootTable, ptr: ?[*]align(arch.paging.page_alignment) u8, num_pages: usize) usize {
    if (ptr == null) {
        // Start from the first page because 0 is used for null pointers. This is a virtual address so we can allocate
        // anywhere in theory.
        return pt.find_range(arch.paging.page_address(1), num_pages);
    }
    return pt.find_range(@intFromPtr(ptr.?), num_pages);
}

pub fn munmap(memory: []align(arch.paging.page_alignment) const u8) void {
    _ = memory;
    @panic("todo implement munmap");
}

fn init_allocator() void {
    if (mem_map_request.response == null) {
        @panic("limine error: failed to get mem_map_request.response");
    }
    const resp = mem_map_request.response.?;

    for (resp.entries()) |e| {
        if (e.kind == limine.MemoryMapEntryType.usable) {
            // Limine guarantees that these regions are 4k aligned
            PageMap.set_usable(e.base, e.base + e.length);
        }
    }
}

// initialises the offset used to map from the higher half virtual memory to physical and back
fn init_higher_half_direct_map() void {
    const maybe_hhdm_response = hhdm_request.response;

    if (maybe_hhdm_response == null) {
        @panic("could not retrieve information about the ram");
    }

    const hhdm_response = maybe_hhdm_response.?;

    hhdm_offset = hhdm_response.offset;
}

pub fn init() void {
    init_higher_half_direct_map();
    init_allocator();
}
