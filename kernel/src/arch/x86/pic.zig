const ports = @import("ports.zig");

pub const master_cmd_port = 0x20;
pub const master_data_port = 0x21;

pub const slave_cmd_port = 0xA0;
pub const slave_data_port = 0xA1;

pub fn disable() void {
    ports.outb(master_data_port, 0xff);
    ports.outb(slave_data_port, 0xff);
}

