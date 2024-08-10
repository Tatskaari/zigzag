const madt = @import("madt.zig");

const terminal = @import("terminal.zig");

const IOREGSEL_OFFSET = 0x0;
const IOWIN_OFFSET = 0x10;

const IOAPICVER = 1;

pub const DeliveryMode = enum(u3) {
    fixed = 0b000,
    lowest = 0b001,
    smi = 0b010,
    nmi = 0b100,
    init = 0b101,
    ext_int = 0b111,
};

pub const DestinationMode = enum(u1) {
    physical = 0,
    logical = 1,
};

pub const Polarity = enum(u1) {
    active_high = 0,
    active_low = 1,
};

pub const TriggerMode = enum(u1) {
    edge = 0,
    level = 1,
};

const APIC = struct {
    // We select which register we want to read from here
    io_reg_select: *u8,
    // We can then read/write the value ehre
    io_window_reg: *u32,

    pub fn read(self: *const APIC, reg: u8) u32 {
        self.io_reg_select.* = reg;
        return self.io_window_reg.*;
    }

    pub fn write(self: *const APIC, reg: u8, value: u32) void {
        self.io_reg_select.* = reg;
        self.io_window_reg.* = value;
    }
};

var RedirectTableEntry = packed struct {
    vector: u8,
    delivery_mode: DeliveryMode,
    destination_mode: DestinationMode,
    delivery_status: u1,
    polarity: Polarity,
    remote_irr: u1,
    trigger_mode: TriggerMode,
    mask: bool,
    reserved: u39 = 0,
    destination: u8,
};


var apic = APIC{
    .io_reg_select = undefined,
    .io_window_reg = undefined,
};


pub fn init() void {
    apic.io_reg_select = @ptrFromInt(madt.io_apic_addr + IOREGSEL_OFFSET);
    apic.io_window_reg = @ptrFromInt(madt.io_apic_addr + IOWIN_OFFSET);

    const number_of_inputs = ((apic.read(IOAPICVER) >> 16) & 0xFF) + 1;
    terminal.print("detected apic with {} inputs", .{number_of_inputs});
}