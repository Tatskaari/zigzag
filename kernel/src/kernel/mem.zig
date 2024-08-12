const std = @import("std");
const limine = @import("limine");

// Limine boots with virutal memory mapping. This is done through a direct mapping, where we have an offset we can apply
// to translate between virtual and physical memory.
//
// See: https://github.com/limine-bootloader/limine/blob/v8.x/PROTOCOL.md#entry-memory-layout
export var hhdm_request: limine.HhdmRequest = .{};

// higher_half_direct_map_offset is the offset used to map from the higher half virutal memory to physical memroy
var hhdm_offset: u64 = undefined;

pub inline fn physical_to_virtual(physical: usize) usize {
    return physical + hhdm_offset;
}

pub inline fn virtual_to_physical(virtual: usize) usize {
    return virtual - hhdm_offset;
}


extern const kernel_end: u8;
var kernel_brk : usize = undefined;

fn sbrk (increment: usize) usize  {
    const last_brk = kernel_brk;
    kernel_brk = kernel_brk + increment;
    // This isn't really a pointer to a u8. It's a watermark in memory so we need to tell zig to trust us here.
    return last_brk;
}


const alloc = std.heap.SbrkAllocator(sbrk);

pub var allocator = std.mem.Allocator{
    .ptr = @ptrCast(@constCast(&alloc)),
    .vtable = &alloc.vtable,
};

fn init_allocator() void {
    kernel_brk = @intFromPtr(&kernel_end);
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