pub const services =  @import("kernel").services;

pub const heap = struct {
    pub const page_allocator = services.mem.PageAllocator.allocator;
};