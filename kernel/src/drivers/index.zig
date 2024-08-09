pub const terminal = @import("terminal.zig");
pub const vga = @import("vga.zig");
pub const pci = @import("pci.zig");
pub const qemu = @import("qemu.zig");
pub const rsdt = @import("rsdt.zig");
pub const madt = @import("madt.zig");
pub const ioapic = @import("ioapic.zig");

pub fn init() void {
    terminal.init();
    rsdt.init();
    madt.init();
    ioapic.init();
}