const drivers = @import("kernel").drivers;
const madt = @import("madt.zig");

// Offsets from the base register for the two of these
const io_reg_select_offset = 0x0;
const io_window_offset = 0x10;

// The version register of the IO APIC
const io_apic_ver_reg = 1;

// The redirect table register of the IO APIC
const io_apic_redirect_table_start_reg = 0x10;

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

    pub fn getNumberOfInputs(self: *const APIC) u32 {
        return ((self.read(io_apic_ver_reg) >> 16) & 0xFF) + 1;
    }

    pub fn writeRedirectEntry(self: *const APIC, entry_num: u8, entry: RedirectTableEntry) void {
        // The value is 64 bit so we use 2 registers per entry
        const offset: u8 = @truncate(io_apic_redirect_table_start_reg + entry_num * 2);
        const value: u64 = @bitCast(entry);

        self.write(offset, @truncate(value));
        self.write(offset+1, @truncate(value >> 32));
    }

    pub fn readRedirectEntry(self: *const APIC, entry_num: u8) RedirectTableEntry {
        // The value is 64 bit so we use 2 registers per entry
        const offset: u8 = @truncate(io_apic_redirect_table_start_reg + entry_num * 2);
        
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
    apic.io_reg_select = @ptrFromInt(madt.io_apic_addr + io_reg_select_offset);
    apic.io_window_reg = @ptrFromInt(madt.io_apic_addr + io_window_offset);

    const ver = apic.read(io_apic_ver_reg);
    drivers.terminal.print("Configured ioapic at 0x{x}, version 0x{x}\n", .{madt.io_apic_addr, ver});
}