const ports = @import("ports.zig");

const PIC_COMMAND_MASTER = 0x20;
const PIC_COMMAND_SLAVE = 0x21;

const PIC_DATA_MASTER = 0xA0;
const PIC_DATA_SLAVE = 0xA1;

const ICW_1 = 0x11;
const ICW_2_M = 0x20;
const ICW_2_S = 0x28;
const ICW_3_M = 0x2;
const ICW_3_S = 0x4;

// We mostly just want to turn off the legacy pic to use the apic
pub fn disable() void {
    ports.outb(PIC_DATA_MASTER, 0xFF);
    ports.outb(PIC_DATA_SLAVE, 0xFF);
}