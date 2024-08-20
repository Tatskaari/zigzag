const kernel =  @import("kernel");

pub const heap = struct {
    pub const page_allocator = kernel.mem.PageAllocator.allocator;
};