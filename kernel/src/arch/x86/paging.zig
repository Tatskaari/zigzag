/// This file implements paging for x86_64
const std = @import("std");

const kernel = @import("kernel");

const limine = @import("limine");

const services = @import("kernel").services;
const drivers = @import("kernel").drivers;
const cpu = @import("cpu.zig");

/// The base address is in terms of pages from 0, not the actually memory address. To convert this, we need to multiply
/// it by the page size, which is 4k i.e. 2^12. We can do this efficiently with a shift left of 12.
const base_address_shift = 12;
pub const page_alignment = 4 * 1024;

/// Each table is 4k in size, and is page aligned i.e. 4k aligned. They consists of 512 64 bit entries.
const page_table_size = 512;

/// PageTable represents a list of 512 entries that make up a layer in the page table structure. Ths same structure is
/// used to represent the PML4, PDPR, PD, and PT levels as they're similar enough for us to do it that way (for now).
const PageTable = struct {
    entries: [page_table_size]PageTableEntry,

    /// page_number returns the physcal page number for the page table based on it's address in memory
    pub fn pageNumber(self: *const PageTable) u40 {
        const address = services.mem.hhdm.physicalFromVirtual(@intFromPtr(self));
        return @truncate(address >> base_address_shift);
    }

    /// alloc_page_table gets a new page from the page table allocator to be used to back a PageTable
    fn allocPageTable() std.mem.Allocator.Error!*PageTable {
        const page = try services.mem.PageMap.alloc();
        const ret: *PageTable = @ptrFromInt(services.mem.hhdm.virtualFromPhysical(page << base_address_shift));
        for (0..ret.entries.len) |i| {
            ret.entries[i].present = false;
        }
        return ret;
    }

    /// set_entry reccursively sets entries in the page table. Will return the physical address of the entry before we
    /// set the entry. This is useful to free the page that was mapped before.
    pub fn setEntry(self: *PageTable, virtual: VirtualMemoryAddress, physical: usize, opts: MapOptions, level: usize) !usize {
        const entry = &self.entries[virtual.idx_for_level(level)];
        // If we're at the final page table level, we want to set the entry to point to the page, not another table.
        if (level == 1) {
            if (entry.present) {
                if(physical == 0) {
                    entry.present = false;
                    return entry.getBaseAddress();
                }
                // TODO do we actually want to allow this?
                @panic("cannot set entry... entry already set");
            }
            const before = self.entries[virtual.idx_for_level(level)].getBaseAddress();
            self.entries[virtual.idx_for_level(level)] = PageTableEntry{
                .writable = opts.writable,
                .user = opts.user,
                .no_exec = opts.no_exec,
                .page_number = @truncate(physical >> base_address_shift),
            };
            return before;
        }

        // Otherwise, ask the sub-page to set the entry
        if (entry.present) {
            return try entry.getTable().setEntry( virtual, physical, opts, level - 1);
        }

        // Create the table if it didn't already exist.
        const table = try allocPageTable();
        _ = try table.setEntry(virtual, physical, opts, level - 1);
        self.entries[virtual.idx_for_level(level)] = PageTableEntry{
            .writable = true,
            .user = false,
            .no_exec = false,
            .page_number = table.pageNumber(),
        };
        return physical;
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

    pub fn getTable(self: *const PageTableEntry) *PageTable {
        // The base address is page aligned, so we have to multiply it by 4kb (our page size)
        // Bitshifting it here effectively does that (2^12 == 4k)
        return @ptrFromInt(services.mem.hhdm.virtualFromPhysical(self.getBaseAddress()));
    }

    pub fn getBaseAddress(self: *const PageTableEntry) usize {
        return self.page_number << base_address_shift;
    }

    /// Returns the page number of the current entry (not the entry it references)
    pub fn getEntryPageNumber(self: *const PageTableEntry) u40 {
        return @truncate(@intFromPtr(self) >> base_address_shift);
    }
};

/// VirtualMemoryAddress represents the 4 levels of a 64bit long mode page table i.e. without the la57
/// (large addressing), feature enabled.
///
/// There are 4 parts that index into the page table/directories at each level, and an offset that indexes into the
/// page itself.
pub const VirtualMemoryAddress = packed struct(u64) {
    offset: u12, // The offset within the page
    page_table: u9, // i.e. the PT entry
    page_dir: u9, // i.e. the PD entry
    page_dir_pointer: u9, // i.e. the PDPR entry
    page_map_level_4: u9, // i.e. the PML4 entry
    sign: u16 = 0, // These are set based on the most significant bit ( of the rest of the bits

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

    /// to_usize cannonicalises the address and converts it to a usize.
    /// This is done by setting the sign on the virutal memroy address by checking the most significant bit i.e. bit 9
    /// of the page_map_level_4 field, which is the x86_64 standard for 48 bit virtual addresses.
    pub fn to_usize(self: *const VirtualMemoryAddress) usize {
        var ret  = self.*;
        if(self.page_map_level_4 & 0x100 != 0) {
            ret.sign = 0xFFFF;
        } else {
            ret.sign = 0;
        }
        return @bitCast(ret);
    }
};

pub const RootTable = struct {
    root: PageTable,

    /// map creates page table entries to map a virutal address to a physical one. Both addresses have to be aligned to
    /// a 4kb boundary.
    pub fn map(self: *RootTable, virtual: usize, physical: usize, options: MapOptions) !void {
        std.debug.assert(@mod(virtual, page_alignment) == 0);
        std.debug.assert(@mod(physical, page_alignment) == 0);
        _ = try self.root.setEntry(@bitCast(virtual), physical, options, 4);
    }

    pub fn unmap(self: *RootTable, virtual: usize) !usize {
        std.debug.assert(@mod(virtual, page_alignment) == 0);
        const opts = MapOptions{.no_exec = false, .writable = false, .user = false};
        return try self.root.setEntry(@bitCast(virtual), 0, opts, 4);
    }

    /// physical_from_virtual walks the page table structure to convert a virtual address to a physical one
    fn physicalFromVirtual(self: *const RootTable, addr: usize) ?usize {
        // The address is broken up into indexes that we can use to look up the page table entries
        const virtual_address: VirtualMemoryAddress = @bitCast(addr);

        // Level 4: Page map level 4
        const pml4_entry = self.root.entries[virtual_address.page_map_level_4];
        if (!pml4_entry.present) {
            return null;
        }

        // Level 3: Page directory pointer (reference?)
        const pdpr_entry = pml4_entry.getTable().entries[virtual_address.page_dir_pointer];
        if (!pdpr_entry.present) {
            return null;
        }

        if (pdpr_entry.big_page_or_pat) {
            @panic("1gb pages not implemented");
        }

        // Level 2: Page directory
        const pd_entry = pdpr_entry.getTable().entries[virtual_address.page_dir];
        if (!pd_entry.present) {
            return null;
        }

        // The page directory can point to a 2mb page, in which case we only have 3 levels. We treat the page table part of
        // the virtual address as part of the offset.
        if (pd_entry.big_page_or_pat) {
            return pd_entry.getBaseAddress() + virtual_address.get_big_page_offset();
        }

        // Level 1: Page table
        const pt_entry = pd_entry.getTable().entries[virtual_address.page_table];
        if (!pt_entry.present) {
            return null;
        }

        // Level 0: the offset within the page table
        return pt_entry.getBaseAddress() + virtual_address.offset;
    }

    /// find_range returns the start address in virutal address space that can fit the requested number of pages
    pub fn findRange(self: *RootTable, hint: usize, page_count: usize) usize {
        var address: usize = hint;

        while(!self.checkRange(address, page_count)) {
            // TODO probably want to implement some kind of max address rather than just litting this integer overflow
            address = address + page_alignment;
        }
        return address;
    }

    /// check_range checks to see if there's a range of virutal memory free at that address for a given number of pages
    fn checkRange(self: *const RootTable, start: usize, len: usize) bool {
        for(0..len)|n| {
            // Check there's no physical address for this virutal address
            if(self.physicalFromVirtual(@bitCast(start + n*page_alignment)) != null) {
                return false;
            }
        }
        return true;
    }
};

/// pageAddressFromNumber returns the page address from the page number
pub fn pageAddressFromNumber(page_number: usize) usize {
    return page_number << base_address_shift;
}

/// pageNumFromAddress returns the page number for a given address
pub fn pageNumFromAddress(address: usize) usize {
    return address >> base_address_shift;
}

/// get_current_page_table returns the page table currently in use i.e. the one cr3 points to
pub fn getCurrentPageTable() *RootTable {
    // csr3 contains the base address of the current page table, but the first 12 bits contains flags that we likely
    // don't care about. They should be set to 0 for us by limine, but we should mask them out just incase.
    // TODO make sure csr3 is set up correctly and all these bits are set to 0
    const physical_addr = cpu.cr3.read() & 0x000FFFFFFFFFFFFF;
    return @ptrFromInt(services.mem.hhdm.virtualFromPhysical(physical_addr));
}
