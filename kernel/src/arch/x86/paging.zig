const limine = @import("limine");
const kernel = @import("kernel");
const cpu = @import("cpu/index.zig");
const std = @import("std");
const drivers = @import("drivers");

// The base address is in terms of pages from 0, not the actually memory address. To convert this, we need to multiply
// it by the page size, which is 4k i.e. 2^12. We can do this efficiently with a shift left of 12.
const base_address_shift = 12;
pub const page_alignment = 4 * 1024;

// Each table is 4k in size, and is page aligned i.e. 4k aligned. They consists of 512 64 bit entries.
const page_table_size = 512;
const PageTable = struct {
    entries: [page_table_size]PageTableEntry,

    /// page_number returns the physcal page number for the page table based on it's address in memory
    pub fn page_number(self: *const PageTable) u40 {
        const address = kernel.mem.physical_from_virtual(@intFromPtr(self));
        return address >> base_address_shift;
    }

    /// alloc_page_table gets a new page from the page table allocator to be used to back a PageTable
    pub fn alloc_page_table() std.mem.Allocator.Error!*PageTable {
        const page = try PageAllocator.alloc();
        const ret: *PageTable = @ptrFromInt(kernel.mem.virtual_from_physical(page << base_address_shift));
        for (0..ret.len) |i| {
            ret[i] = @bitCast(0);
        }
        return ret;
    }

    /// set_entry reccursively sets entries in the page table
    pub fn set_entry(self: *PageTable,virtual: VirtualMemoryAddress, physical: usize, opts: MapOptions, level: usize) !void {
        const entry = self.entries[virtual.idx_for_level(level)];
        // If we're at the final page table level, we want to set the entry to point to the page, not another table.
        if (level == 1) {
            if (entry.present) {
                @panic("cannot set entry... entry already set");
            }
            self.entries[virtual.idx_for_level(level)] = PageTableEntry{
                .writable = opts.writable,
                .user = opts.user,
                .no_exec = opts.no_exec,
                .page_number = physical >> base_address_shift,
            };
            return;
        }

        // Otherwise, ask the sub-page to set the entry
        if (entry.present) {
            entry.get_table().set_entry( virtual, physical, opts, level - 1);
            return;
        }

        // Create the table if it didn't already exist.
        const table = try alloc_page_table();
        table.set_entry(virtual, physical, opts, level - 1);
        self.entries[virtual.idx_for_level(level)] = PageTableEntry{
            .writable = opts.writable,
            .user = opts.user,
            .no_exec = opts.no_exec,
            .page_number = table.page_number(),
        };
    }
};

pub const MapOptions = struct {
    user: bool,
    writable: bool,
    no_exec: bool,
};

/// Each level in the page table has essentially the same structure. They're a base address wrapped with some flags. You
/// would normally mask our the base address in C/C++, but zig lets us use a packaged struct like this.
///
/// This struct pretty much captures everything we need. Some fields only make sense at certian levels though. See
/// comments.
const PageTableEntry = packed struct(u64) {
    /// True of the entry exists in the page table
    present: bool = true,
    /// If set to false, nothing under this entry is writeable. If set to true, the entries under it can still override
    /// this.
    writable: bool,
    /// If set to false, this page is only usable in supervisor CPU protection levels. Same rules apply as writable for
    /// entries under here overrding this.
    user: bool,
    /// The next two control stuff around caching that I don't really care about at this point.
    write_through: bool = false,
    no_cache: bool = false,
    /// PT only: Whether this page table has been accessed. This is set by the CPU when it does an address translation.
    /// Not very useful to us (yet?)
    accessed: bool = false,
    /// PT onlye: Similar to above: whether the page table entry has been modified by the CPU
    dirty: bool = false,
    /// PD and PDPR only: If set, this is the last level in the page levels. The address points to a big page i.e. a
    /// 1gb (for PDPR) or 2mb (for PD) page, not a page table entry.
    /// PT only: Is the Page Attribute Table which isn't very useful to us
    big_page_or_pat: bool = false,
    /// PT only: Something to do with ejecting the page when a context switch happens. Might help with cache performance?
    global: bool = false,
    reserved_1: u3 = 0,
    /// The page number this references. Multiplying this by the page size gives us the physical memory address.
    page_number: u40,
    reserved_2: u11 = 0,
    /// Whether memory in this page should not be executed i.e. is data not code
    no_exec: bool = false,

    pub fn get_table(self: *const PageTableEntry) *PageTable {
        // The base address is page aligned, so we have to multiply it by 4kb (our page size)
        // Bitshifting it here effectively does that (2^12 == 4k)
        return @ptrFromInt(kernel.mem.virtual_from_physical(self.get_base_address()));
    }

    pub fn get_base_address(self: *const PageTableEntry) usize {
        return self.page_number << base_address_shift;
    }

    /// Returns the page number of the current entry (not the entry it references)
    pub fn get_entry_page_number(self: *const PageTableEntry) u40 {
        return @truncate(@intFromPtr(self) >> base_address_shift);
    }
};

/// PageAllocator is an allocator that will allocate and free free pages, using a bitmap to keep track of which pages
/// are currently allocated.
///
/// Note: this is not an implementation of std.mem.Allocator. This would be used to implement mmap which in turn would
/// be used by std.heap.PageAllocator.
pub const PageAllocator = struct {
    // Allows for up to 2 TB of memory. This is simple and avoids the need to allocate memory before we have a memory
    // allocator.
    var map: [4 * 1024 * 1024]u64 = [_]u64{std.math.maxInt(u64)} ** (4 * 1024 * 1024); // initialise with all bits set (no free mem)
    var total_pages: usize = undefined;
    var map_len: usize = undefined;

    /// init will initialise the page allocator with a given max page size. This should be set based on the total memroy
    /// that the system has
    pub fn init(max_pages: usize) void {
        total_pages = max_pages;
        map_len = std.math.divCeil(usize, total_pages, 64) catch unreachable;
        if (map_len > map.len) {
            @panic("page allocator can only allocate up to 2 TB of memory");
        }
    }

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
        const from_page = @divExact(from_addr, page_alignment);
        const to_page = @divExact(to_addr, page_alignment);

        for(from_page..to_page) |i| {
            free(i);
        }
    }
};

/// VirtualMemoryAddress represents the 4 level of a 64bit long mode page table without the la57 (large addressing using
/// 57-bits), feature enabled. This feature is only really relevent on super computers with stupid amounts of RAM, so
/// we'll just pretend it doesn't exist.
pub const VirtualMemoryAddress = packed struct(u64) {
    offset: u12, // The offset within the page
    page_table: u9, // i.e. the PT entry
    page_dir: u9, // i.e. the PD entry
    page_dir_pointer: u9, // i.e. the PDPR entry
    page_map_level_4: u9, // i.e. the PML4 entry
    reserved: u16 = 0xFFFF, // We have some bits to spare that should always be 1.

    /// For big (2mb) page tables we use both the page table and the offset fields as the offset
    pub fn get_big_page_offset(self: *const VirtualMemoryAddress) usize {
        return (@as(usize, self.page_table) << 12) + self.offset;
    }

    pub fn idx_for_level(self: *const VirtualMemoryAddress, level: usize) u9 {
        switch (level) {
            1 => return self.page_table,
            2 => return self.page_dir,
            3 => return self.page_dir_pointer,
            4 => return self.page_map_level_4,
            else => unreachable,
        }
    }
};

pub const RootTable = struct {
    root: PageTable,

    /// map creates page table entries to map a virutal address to a physical one. Both addresses have to be aligned to
    /// a 4kb boundary.
    pub fn map(self: *RootTable, virtual: usize, physical: usize, options: MapOptions) !void {
        std.debug.assert(@mod(virtual, page_alignment) == 0);
        std.debug.assert(@mod(physical, page_alignment) == 0);
        self.root.set_entry(@bitCast(virtual), physical, options, 4);
    }

    // physical_from_virtual walks the page table structure to convert a virtual address to a physical one
    pub fn physical_from_virtual(self: *const RootTable, addr: usize) ?usize {
        // The address is broken up into indexes that we can use to look up the page table entries
        const virtual_address: VirtualMemoryAddress = @bitCast(addr);

        // Level 4: Page map level 4
        const pml4_entry = self.root.entries[virtual_address.page_map_level_4];
        if (!pml4_entry.present) {
            return null;
        }

        // Level 3: Page directory pointer (reference?)
        const pdpr_entry = pml4_entry.get_table().entries[virtual_address.page_dir_pointer];
        if (!pdpr_entry.present) {
            return null;
        }

        if (pdpr_entry.big_page_or_pat) {
            @panic("1gb pages not implemented");
        }

        // Level 2: Page directory
        const pd_entry = pdpr_entry.get_table().entries[virtual_address.page_dir];
        if (!pd_entry.present) {
            return null;
        }

        // The page directory can point to a 2mb page, in which case we only have 3 levels. We treat the page table part of
        // the virtual address as part of the offset.
        if (pd_entry.big_page_or_pat) {
            return pd_entry.get_base_address() + virtual_address.get_big_page_offset();
        }

        // Level 1: Page table
        const pt_entry = pd_entry.get_table().entries[virtual_address.page_table];
        if (!pd_entry.present) {
            return null;
        }

        // Level 0: the offset within the page table
        return pt_entry.get_base_address() + virtual_address.offset;
    }
};

pub fn get_current_page_table() *RootTable {
    // csr3 contains the base address of the current page table, but the first 12 bits contains flags that we likely
    // don't care about. They should be set to 0 for us by limine, but we should mask them out just incase.
    // TODO make sure csr3 is set up correctly and all these bits are set to 0
    const physical_addr = cpu.cr3.read() & 0x000FFFFFFFFFFFFF;
    return @ptrFromInt(kernel.mem.virtual_from_physical(physical_addr));
}

pub fn init() void {
    var length : usize = 0;
    const resp = kernel.mem.mem_map_request.response.?;
    for (resp.entries()) |e| {
        if (e.kind == limine.MemoryMapEntryType.usable) {
            PageAllocator.set_usable(e.base, e.base + e.length);
            if(e.base+e.length > length) {
                length = e.base + e.length;
            }

            drivers.terminal.print("setting usable 0x{x}\n", .{e.base});
        }
    }

    PageAllocator.init(@divExact(length, page_alignment));
}