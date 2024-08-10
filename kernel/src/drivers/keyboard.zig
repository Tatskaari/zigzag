const arch = @import("arch");
const terminal = @import("terminal.zig");

const DATA = 0x60;
const STATUS = 0x64;
const COMMAND = STATUS;

export fn keyboard_isr() callconv(.Interrupt) void {
    const scancode = arch.ports.inb(DATA);
    terminal.print("Scancode read: 0x{x}\n", .{scancode});
}