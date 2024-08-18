/// PageMap frees and allocates in use pages, using a bitmap to keep track of which pages are currently allocated.
const std = @import("std");
const arch = @import("arch");

// Allows for up to 2 TB of memory. This is simple and avoids the need to allocate memory before we have a memory
// allocator.
var map: [4 * 1024 * 1024]u64 = [_]u64{std.math.maxInt(u64)} ** (4 * 1024 * 1024); // initialise with all bits set (no free mem)
var total_pages: usize = 0;
var map_len: usize = 0;

/// free will mark an already allocated page as free
pub fn free(page_num: usize) void {
    const idx = @divFloor(page_num, 64);
    const mask = ~(@as(usize, 1) << @intCast(@mod(page_num, 64)));

    map[idx] = map[idx] & mask;
}

/// alloc will find the first free page number, mark it as allocated and return
pub fn alloc() std.mem.Allocator.Error!usize {
    for (0..map_len) |i| {
        if (map[i] == std.math.maxInt(u64)) {
            continue; // all bits are set. No free memory here.
        }
        // Otherwise loop through each bit to find the free one
        const quad = map[i];
        for (0..64) |j| {
            const mask = @as(usize, 1) << @intCast(j);
            if (quad & mask == 0) {
                map[i] = map[i] | mask;
                const page_num = i * 64 + j;
                if (page_num > total_pages) {
                    return std.mem.Allocator.Error.OutOfMemory;
                }
                return page_num;
            }
        }
    }
    return std.mem.Allocator.Error.OutOfMemory;
}

/// set_usable sets a range of physical memory to be useable to allocate pages. The start and end address must be
/// page aligned.
pub fn set_usable(from_addr: usize, to_addr: usize) void {
    const from_page = @divExact(from_addr, arch.paging.page_alignment);
    const to_page = @divExact(to_addr, arch.paging.page_alignment);

    if(to_page > total_pages) {
        total_pages = to_page;
        map_len = std.math.divCeil(usize, total_pages, 64) catch unreachable;
    }

    for(from_page..to_page) |i| {
        free(i);
    }
}