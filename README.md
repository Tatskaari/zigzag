# zigzag is an operating system with a terrible name
It's written from scratch, with love, in zig. 

## Roadmap

Currently trying to figure out the feature set needed to port binutils and a shell (zsh maybe?).

The feaures are loosely:
- A userspace
- A TTY implementation
- A libc port (should be easy enough once we have a posix like abi)
- A filesystem

The roadmap to achieve this is:

- [x] VGA graphics mode
- [x] VGA terminal
- [x] Initialise the interrupt descriptor table
- [x] MoreCore allocator
- [ ] Configure the GDT (set the kernel cs and ds)
- [x] Read the root system descriptor table
- [x] Read the MADT
- [x] APIC setup
- [x] PS/2 Keyboard input
- [x] PIT timer
- [x] Paging: allocating pages and mapping them to virtual addresses
- [x] Paging: mmap and a std.heap.PageAllocator
- [x] Lapic timer
- [x] Scheduler (basic scheduling of threads)
  - [ ] Implement wait, yield and sleep
  - [ ] Implement an event queue and terminal thread that listens to keyboard events
  - [ ] Run lspci from the keybaord listener as a thread
- [ ] Implement the proc/sys filesystems for pci devices
- [ ] Processes and elf loading: move lspci out into its own binary
- [ ] Basic userspace + entrypoint
- [ ] Syscall ABI for memory mapping
- [ ] Filesystem service for embedded tar 
- [ ] Keyboard service
- [ ] TTY service
- [x] PCI device discovery
- [ ] SATA/IDE driver
- [ ] Read/write FAT-32 filesystem (over IDE)
- [ ] Open and write syscalls
- [ ] Create a standard library for userspace programmes
- [ ] Exec syscall
- [ ] Fork syscall
