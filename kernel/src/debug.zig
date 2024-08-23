const std = @import("std");
const kernel = @import("kernel");

pub fn print(comptime fmt: []const u8, args: anytype) void {
    if (kernel.drivers.terminal.tty.initialised) {
        const writer = kernel.drivers.terminal.tty.writer();
        std.fmt.format(writer, fmt, args) catch return;
        return;
    }
    if (kernel.drivers.serial.COM1.initialised) {
        const writer = kernel.drivers.serial.COM1.writer();
        std.fmt.format(writer, fmt, args) catch return;
        return;
    }
}

