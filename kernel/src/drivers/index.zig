pub const terminal = @import("terminal.zig");
pub const vga = @import("vga.zig");
pub const pci = @import("pci.zig");
pub const qemu = @import("qemu.zig");
pub const keyboard = @import("keyboard.zig");

pub fn init() void {
    terminal.init();
    keyboard.init();
}