pub const terminal = @import("terminal.zig");
pub const vga = @import("vga.zig");
pub const qemu = @import("qemu.zig");
pub const keyboard = @import("keyboard/keyboard.zig");

pub fn init() void {
    keyboard.init();
}