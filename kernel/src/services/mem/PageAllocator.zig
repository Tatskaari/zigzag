/// PageAllocator is a modified version of the PageAllocator from the stdlib to work with our kernel ABI

const arch = @import("kernel").arch;
const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const maxInt = std.math.maxInt;
const assert = std.debug.assert;

const mem = @import("mem.zig");

pub const vtable = Allocator.VTable{
    .alloc = alloc,
    .resize = resize,
    .free = free,
};

pub const allocator = std.mem.Allocator{
    .ptr = undefined,
    .vtable = &vtable,
};

fn alloc(_: *anyopaque, n: usize, _: u8, _: usize) ?[*]u8 {
    assert(n > 0);
    if (n > maxInt(usize) - (arch.paging.page_alignment - 1)) return null;

    const aligned_len = std.mem.alignForward(usize, n, arch.paging.page_alignment);
    const hint = @atomicLoad(@TypeOf(std.heap.next_mmap_addr_hint), &std.heap.next_mmap_addr_hint, .unordered);
    const slice = mem.mmap(
        hint,
        aligned_len,
        mem.PROT.READ | mem.PROT.WRITE,
    ) catch return null;
    assert(std.mem.isAligned(@intFromPtr(slice.ptr), arch.paging.page_alignment));
    const new_hint: [*]align(arch.paging.page_alignment) u8 = @alignCast(slice.ptr + aligned_len);
    _ = @cmpxchgStrong(@TypeOf(std.heap.next_mmap_addr_hint), &std.heap.next_mmap_addr_hint, hint, new_hint, .monotonic, .monotonic);
    return slice.ptr;
}

fn resize(
    _: *anyopaque,
    _: []u8,
    _: u8,
    _: usize,
    _: usize,
) bool {
    @panic("resizing not implemented");
}

fn free(_: *anyopaque, slice: []u8, _: u8, _: usize) void {
    const buf_aligned_len = std.mem.alignForward(usize, slice.len, arch.paging.page_alignment);
    mem.munmap(@alignCast(slice.ptr[0..buf_aligned_len]));
}
