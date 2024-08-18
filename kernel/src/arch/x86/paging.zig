const limine = @import("limine");
const kernel = @import("kernel");
const cpu = @import("cpu/index.zig");


// The base address is in terms of pages from 0, not the actually memory address. To convert this, we need to multiply
// it by the page size, which is 4k i.e. 2^12. We can do this efficiently with a shift left of 12.
const base_address_shift = 12;

// Each table is 4k in size, and is page aligned i.e. 4k aligned. They consists of 512 64 bit entries.
const PageTable = struct {
    entries: [512]PageTableEntry,
};

// Each level in the page table has essentially the same structure. They're a base address wrapped with some flags. You
// would normally mask our the base address in C/C++, but zig lets us use a packaged struct like this.
//
// This struct pretty much captures everything we need. Some fields only make sense at certian levels though. See
// comments.
// TODO refactor these out into separate structs for each level.
const PageTableEntry = packed struct(u64) {
    // True of the entry exists in the page table
    present: bool = false,
    // If set to false, nothing under this entry is writeable. If set to true, the entries under it can still override
    // this.
    writable: bool = false,
    // If set to false, this page is only usable in supervisor CPU protection levels. Same rules apply as writable for
    // entries under here overrding this.
    user: bool = false,
    // The next two control stuff around caching that I don't really care about at this point.
    write_through: bool = false,
    no_cache: bool = false,
    // PT only: Whether this page table has been accessed. This is set by the CPU when it does an address translation.
    // Not very useful to us (yet?)
    accessed: bool = false,
    // PT onlye: Similar to above: whether the page table entry has been modified by the CPU
    dirty: bool = false,
    // PD and PDPR only: If set, this is the last level in the page levels. The address points to a big page i.e. a
    // 1gb (for PDPR) or 2mb (for PD) page, not a page table entry.
    // PT only: Is the Page Attribute Table which isn't very useful to us
    big_page_or_pat: bool = false,
    // PT only: Something to do with ejecting the page when a context switch happens. Might help with cache performance?
    global: bool = false,
    reserved_1: u3 = 0,
    // The page number this references. Multiplying this by the page size gives us the physical memory address.
    page_number: u40 = 0,
    reserved_2: u11 = 0,
    // Whether memory in this page should not be executed i.e. is data not code
    no_exe: bool = false,

    pub fn get_table(self: *const PageTableEntry) *PageTable {
        // The base address is page aligned, so we have to multiply it by 4kb (our page size)
        // Bitshifting it here effectively does that (2^12 == 4k)
        return @ptrFromInt(kernel.mem.virtual_from_physical(self.get_base_address()));
    }

    pub fn get_base_address(self: *const PageTableEntry) usize {
        return self.page_number << base_address_shift;
    }
};


// VirtualMemoryAddress represents the 4 level of a 64bit long mode page table without the la57 (large addressing using
// 57-bits), feature enabled. This feature is only really relevent on super computers with stupid amounts of RAM, so
// we'll just pretend it doesn't exist.
pub const VirtualMemoryAddress = packed struct (u64) {
    offset: u12, // The offset within the page
    page_table: u9, // i.e. the PT entry
    page_dir: u9, // i.e. the PD entry
    page_dir_pointer: u9, // i.e. the PDPR entry
    page_map_level_4: u9, // i.e. the PML4 entry
    reserved: u16 = 0xFFFF, // We have some bits to spare that should always be 1.

    // For big (2mb) page tables we use both the page table and the offset fields as the offset
    pub fn get_big_page_offset(self: *const VirtualMemoryAddress) usize {
        return (@as(usize, self.page_table) << 12) + self.offset;
    }
};

// physical_from_virtual walks the page table structure to convert a virtual address to a physical one
pub fn physical_from_virtual(pml4: *PageTable, addr: usize) ?usize {
    // The address is broken up into indexes that we can use to look up the page table entries
    const virtual_address : VirtualMemoryAddress = @bitCast(addr);

    // Level 4: Page map level 4
    const pml4_entry = pml4.entries[virtual_address.page_map_level_4];
    if(!pml4_entry.present) {
        return null;
    }

    // Level 3: Page directory pointer (reference?)
    const pdpr_entry = pml4_entry.get_table().entries[virtual_address.page_dir_pointer];
    if(!pdpr_entry.present) {
        return null;
    }

    // TODO I think the pdpr can have the big page field set and that means it's a 1gb page

    // Level 2: Page directory
    const pd_entry = pdpr_entry.get_table().entries[virtual_address.page_dir];
    if(!pd_entry.present) {
        return null;
    }

    // The page directory can point to a 2mb page, in which case we only have 3 levels. We treat the page table part of
    // the virtual address as part of the offset.
    if (pd_entry.big_page_or_pat) {
        return pd_entry.get_base_address() + virtual_address.get_big_page_offset();
    }

    // Level 1: Page table
    const pt_entry = pd_entry.get_table().entries[virtual_address.page_table];
    if(!pd_entry.present) {
        return null;
    }

    // Level 0: the offset within the page table
    return pt_entry.get_base_address() + virtual_address.offset;
}

pub fn get_current_page_table() *PageTable {
    // csr3 contains the base address of the current page table, but the first 12 bits contains flags that we likely
    // don't care about. They should be set to 0 for us by limine, but we should mask them out just incase.
    // TODO make sure csr3 is set up correctly and all these bits are set to 0
    const physical_addr = cpu.cr3.read() & 0x000FFFFFFFFFFFFF;
    return @ptrFromInt(kernel.mem.virtual_from_physical(physical_addr));
}