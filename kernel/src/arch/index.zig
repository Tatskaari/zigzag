// We can switch on the target arch here to swap out the CPU related stuff e.g. init the IDT in 64 bit mode
pub usingnamespace @import("x86/index.zig");
pub const rsdt = @import("rsdt.zig");
pub const pci = @import("pci.zig");
