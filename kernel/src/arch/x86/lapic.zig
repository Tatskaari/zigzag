const hhdm = @import("kernel").services.mem.hhdm;
const kernel = @import("kernel");
const msr = @import("cpu.zig").msr;

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

    pub fn enable(self: *const APIC) void {
        self.write(spurious_int_reg, self.read(spurious_int_reg) | 0x100);
        self.write(0x380, 0);
    }
};

pub fn get_lapic() APIC {
    // TODO cache these by cpu id
    return APIC{.base = hhdm.virtualFromPhysical(msr.read(apic_base_msr_reg) & 0xFFFFF000)};
}

pub fn init() void {
    // TODO for each CPU once we enter MP
    get_lapic().enable();
}