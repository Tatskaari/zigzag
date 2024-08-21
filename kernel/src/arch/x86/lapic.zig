const kernel = @import("kernel");
const terminal = @import("drivers").terminal;
const msr = @import("cpu/index.zig").msr;

const apic_base_msr_reg = 0x1B;
const spurious_int_reg = 0xF0;

const id_reg = 0x20;
const ver_reg = 0x30;
const eoi_reg = 0xB0;

const APIC = struct {
    base: usize,

    pub fn write(self: *const APIC, reg: usize, value: u32) void {
        const val: *u32 = @ptrFromInt(self.base + reg);
        val.* = value;
    }

    pub fn read(self: *const APIC, reg: usize) u32 {
        const val: *u32 = @ptrFromInt(self.base + reg);
        return val.*;
    }

    pub fn getId(self: *const APIC) u32 {
        const id = self.read(id_reg);
        return id;
    }

    pub fn end(self: *const APIC) void {
        self.write(eoi_reg, 0);
    }
};

pub var bootstrap_apic = APIC{.base = undefined};

pub fn get_lapic() APIC {
    // TODO cache these by cpu id
    return APIC{.base = kernel.mem.hhdm.virtualFromPhysical(msr.read(apic_base_msr_reg) & 0xFFFFF000)};
}

pub fn init() void {
    bootstrap_apic.base = kernel.mem.hhdm.virtualFromPhysical(msr.read(apic_base_msr_reg) & 0xFFFFF000);

    // To enable the lapic, we set the sprious interrupt reg to 0xFF, and set the enable (8th bit) to 1
    bootstrap_apic.write(spurious_int_reg, bootstrap_apic.read(spurious_int_reg) | 0x100);
    bootstrap_apic.write(0x380, 0);

    terminal.print("lapic version 0x{x}\n", .{bootstrap_apic.read(ver_reg)});
}