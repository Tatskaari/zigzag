const std = @import("std");
const limine = @import("limine");

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

var brk: usize = undefined;
var max_brk: usize = undefined;

fn sbrk (increment: usize) usize  {
    const last_brk = brk;
    brk = brk + increment;
    if (brk > max_brk) {
        return 0;
    }
    return last_brk;
}


const alloc = std.heap.SbrkAllocator(sbrk);

pub var allocator = std.mem.Allocator{
    .ptr = @ptrCast(@constCast(&alloc)),
    .vtable = &alloc.vtable,
};

fn init_allocator() void {
    if(mem_map_request.response == null) {
        @panic("limine error: failed to get mem_map_request.response");
    }
    const resp = mem_map_request.response.?;

    // Find the largest useable entry
    var best_entry : ?*limine.MemoryMapEntry = null;
    for(resp.entries()) |entry| {
        if(entry.kind != limine.MemoryMapEntryType.usable) {
            continue;
        }
        if(best_entry == null) {
            best_entry = entry;
            continue;
        }
        if(entry.length > best_entry.?.length) {
            best_entry = entry;
        }
    }

    if(best_entry == null) {
        @panic("can't find any useable memory for sbrk");
    }
    brk = virtual_from_physical(best_entry.?.base);
    max_brk = brk + best_entry.?.length;
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