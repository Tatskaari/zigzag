const ports = @import("ports.zig");

pub const MASTER_CMD_PORT = 0x20;
pub const MASTER_DATA_PORT = 0x21;

pub const SLAVE_CMD_PORT = 0xA0;
pub const SLAVE_DATA_PORT = 0xA1;

pub fn disable() void {
    ports.outb(MASTER_DATA_PORT, 0xff);
    ports.outb(SLAVE_DATA_PORT, 0xff);
}

