const drivers = @import("drivers");
const madt = @import("madt.zig");

const IOREGSEL_OFFSET = 0x0;
const IOWIN_OFFSET = 0x10;

// The version register of the IO APIC
const IOAPICVER_REG = 1;

// The redirect table register of the IO APIC
const IOAPIC_REDTBL_START = 0x10;

pub const DeliveryMode = enum(u3) {
    fixed = 0b000,
    lowest = 0b001,
    smi = 0b010,
    nmi = 0b100,
    init = 0b101,
    ext_int = 0b111,
};

pub const DestinationMode = enum(u1) {
    // When using physical we can use the lapic address as the destination
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

pub const RedirectTableEntry = packed struct {
    vector: u8,
    delivery_mode: DeliveryMode,
    destination_mode: DestinationMode,
    delivery_status: u1 = 0,
    polarity: Polarity,
    remote_irr: u1,
    trigger_mode: TriggerMode,
    mask: bool,
    reserved: u39 = 0,
    destination: u8,
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

    pub fn get_number_of_inputs(self: *const APIC) u32 {
        return ((self.read(IOAPICVER_REG) >> 16) & 0xFF) + 1;
    }

    pub fn write_redirect_entry(self: *const APIC, entry_num: u8, entry: RedirectTableEntry) void {
        // The value is 64 bit so we use 2 registers per entry
        const offset: u8 = @truncate(IOAPIC_REDTBL_START + entry_num * 2);
        const value: u64 = @bitCast(entry);

        self.write(offset, @truncate(value));
        self.write(offset+1, @truncate(value >> 32));
    }

    pub fn read_redirect_entry(self: *const APIC, entry_num: u8) RedirectTableEntry {
        // The value is 64 bit so we use 2 registers per entry
        const offset: u8 = @truncate(IOAPIC_REDTBL_START + entry_num * 2);
        
        const lo : u64 = @intCast(self.read(offset));
        const hi : u64 = @intCast(self.read(offset+1));

        return @bitCast((hi << 32) + lo);
    }
};

pub var apic = APIC{
    .io_reg_select = undefined,
    .io_window_reg = undefined,
};

pub fn init() void {
    apic.io_reg_select = @ptrFromInt(madt.io_apic_addr + IOREGSEL_OFFSET);
    apic.io_window_reg = @ptrFromInt(madt.io_apic_addr + IOWIN_OFFSET);

    const ver = apic.read(IOAPICVER_REG);
    drivers.terminal.print("ioapic ver 0x{x}\n", .{ver});
}