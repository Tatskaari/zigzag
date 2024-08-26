const kernel = @import("kernel");
const ports = @import("ports.zig");
const idt = @import("idt.zig");
const cpu = @import("cpu.zig");
const ioapic = @import("ioapic.zig");
const lapic = @import("lapic.zig");

const redtable_entry_num = 2;

const chan_0_data_port = ports.new(0x40);
const chan_1_data_port = ports.new(0x41);
const chant_2_data_port = ports.new(0x42);
const cmd_register = ports.new(0x43);

const CmdRegisterBitFields = packed struct(u8) {
    bcd_on: u1 = 0, // 0 for binary, 1 for binary coded decimal
    mode: u3,
    access_mode: u2 = 0b11, // 0b11 to send the low then high
    channel: u2 = 0, // We always use channel 0
};

const modes = struct {
    const periodic = 2;
    const one_shot = 0;
};

pub fn setInterval(count: u16) void {
    const cmd_byte: u8 = @bitCast(CmdRegisterBitFields{ .mode = modes.periodic });

    cmd_register.write(cmd_byte);

    const lo: u8 = @truncate(count & 0xFF);
    const hi: u8 = @truncate(count >> 8);

    chan_0_data_port.write(lo); //low-byte
    chan_0_data_port.write(hi);
}

pub fn oneShot(count: u16) void {
    const cmd_byte: u8 = @bitCast(CmdRegisterBitFields{ .mode = modes.one_shot });

    cmd_register.write(cmd_byte);

    const lo: u8 = @truncate(count & 0xFF);
    const hi: u8 = @truncate(count >> 8);

    chan_0_data_port.write(lo); //low-byte
    chan_0_data_port.write(hi);
}


pub const Callback = struct {
    context: *anyopaque,
    func: *const fn (*anyopaque) void,
};

var callback: Callback = undefined;
pub fn isr(_: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    callback.func(callback.context);
    lapic.getLapic().end();
}

pub fn init(apic: *const ioapic.APIC, handler: Callback) void {
    callback = handler;

    const idt_vec = idt.registerInterrupt(&isr, 0);

    var entry = apic.readRedirectEntry(redtable_entry_num);
    entry.mask = false;
    entry.vector = idt_vec;
    entry.destination_mode = ioapic.DestinationMode.physical;
    entry.destination = @truncate(lapic.getLapic().getId());
    apic.writeRedirectEntry(redtable_entry_num, entry);

    // this comes out at roughly 1ms pulses as the clock is around 1.2mhz
    setInterval(1194);
}
