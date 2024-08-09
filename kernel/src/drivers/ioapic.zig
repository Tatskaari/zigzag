const madt = @import("madt.zig");

const terminal = @import("terminal.zig");

const IOWIN_OFFSET = 0x10;

const IOAPICVER = 1;

const APIC = struct {
    // We select which register we want to read from here
    io_reg_select: *u8,
    // We can then read/write the value ehre
    io_window_reg: *u32,

    pub fn read(self: *const APIC, reg: u8) u32 {
        self.io_reg_select.* = reg;
        return self.io_window_reg.*;
    }
};

var apic = APIC{
    .io_reg_select = undefined,
    .io_window_reg = undefined,
};

pub fn init() void {
    const apic_addr = madt.madt.get_io_apic_addr();
    apic.io_window_reg = @ptrFromInt(apic_addr + IOWIN_OFFSET);
    apic.io_reg_select = @ptrFromInt(madt.madt.get_io_apic_addr());

    const number_of_inputs = ((apic.read(IOAPICVER) >> 16) & 0xFF) + 1;
    terminal.print("detected apid with {} inputs", .{number_of_inputs});

}