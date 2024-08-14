In real and protected modes, x86 can use segmentation to control how memory can be accessed, however in long mode, segmentation is disabled, so paging must be used to implement memory protection. 

When using paging, the memory is presented as one contiguous piece of memory with no segmentation. This isn't actually the case though. This contiguous memory in virtual space, is actually broken up into pages that are each individually mapped somewhere in physical space. 

In posix kernels, processes can request pages from the kernel via the `mmap` command. This is how they grow their heap. The kernel can set protections on the memory the process gets page by page. 

This is done through data structures called page directories and page tables. These are structures in memory that are pointed to by `CR3`, which the memory management unit (MMU) uses to translate virtual memory addresses to physical ones. 

This means that each process sees a totally flat address space with no segmentation. Pages can be paged in to the virtual address space to give the process access to a controlled part of memory. This mean operating systems can reclaim and allocate pages, making them available to user space program. 

Each page can have it's own protection, which replaces the access controls that protected mode provide through the GDT. This allows us to control which memory is available in each virtual address space for each user process, and whether this is writable etc. 

# Overview

The steps to setting up paging are:

1) If you're not already, enable paging by setting various `cr` registers
2) Create your page tables in memory 
3) Set `cr3` to this memory address

The CPU will begin executing code using this page table data to virtualize memory. A page allocator can be used to add new pages to this structure as needed. To do this typically you use a bitmap to keep track of what memory is available: 

1) Read in the usable portions of memory from your bootloader
2) For each 4k chunk, set a bit in your bitmap to 1, otherwise set a 0
3) To find a new chunk of memory to use for a page, search for the first 1 and set it to 0
4) When a page is returned, set that chunk back to 0

The page allocator can use this information to find a free section of memory, and add it to the page table. 

# Page tables: address translation

The translation between virtual to physical address space is done through page directories and tables that are loaded into memory. The MMU then reads these and uses them to translate a virtual address to a physical address. 

Page sizes are defined by the architecture, but essentially they're 4kb on x86. It's possible on 64bit machines to use larger page sizes of 2mb or 1gb but this is for performance reasons so it's largely unnecessary to consider here. 

For x86 systems, there are 2 page directories, and a page table. For x86_64 systems, there are 4 directories and 1 page table (for 4kb page sizes). The virtual address is broken down into parts, which reference entries in directories, where the penultimate part references a page in a page table, and the last part references a memory offset within that page. 

Here's how that works for 32 bit addresses: 
![[32bit address translation.png]]

This allows for efficient lookups. The MMU also caches these in something called the translation lookaside buffer (TLB), avoiding having to read the page information from system memory again. 

## Long mode page tables

In long mode, the structure of the page directories/tables is:

- Root page table:  Page-Map Level-4 Table (PML4),
- Second page table: Page-Directory Pointer Table (PDPR),
- Third page table: the Page-Directory Table (PD),
- and finally the Page Table (PT).

The address of the root page table should be written to csr3:

```
asm volatile ("mov %[value], %cr3"
	:
	: [value] "{rax}" (value),
	: "memory"
);
```

