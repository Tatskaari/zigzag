pub const kernel =  @import("root").kernel;

pub const heap = struct {
    pub const page_allocator = kernel.mem.PageAllocator.allocator;
};