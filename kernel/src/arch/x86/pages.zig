const limine = @import("limine");

pub export var mem_map_request = limine.MemoryMapRequest{};

/// PML4: The top level in the paging tree. Points to PDPRs
const PageMapLevelFour = struct {

};

/// PDPR: The second level. Points to page directories. Has the same structure as the page directory
const PageDirectoryPointerRegistry = struct {

};

/// The penultimate layer in the paging struction. Points to page tables.
const PageDirectory = struct {

};

/// The page table itself containing actual pointers to regions of memory i.e. the pages
const PageTable = struct {

};

