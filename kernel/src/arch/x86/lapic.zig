const kernel = @import("kernel");
const terminal = @import("drivers").terminal;
const msr = @import("msr.zig");

const APIC_BASE_MSR_REG = 0x1B;
const SPURIOUS_INT_REG = 0xF0;

const ID_REG = 0x20;
const VER_REG = 0x30;
const EOI_REG = 0xB0;

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

    pub fn get_id(self: *const APIC) u32 {
        const id = self.read(ID_REG);
        return id;
    }

    pub fn end(self: *const APIC) void {
        self.write(EOI_REG, 0);
    }
};

pub var bootstrap_apic = APIC{.base = undefined};

pub fn get_lapic() APIC {
    // TODO cache these by cpu id
    return APIC{.base = kernel.mem.physical_to_virtual(msr.read(APIC_BASE_MSR_REG) & 0xFFFFF000)};
}

pub fn init() void {
    bootstrap_apic.base = kernel.mem.physical_to_virtual(msr.read(APIC_BASE_MSR_REG) & 0xFFFFF000);

    // I don't think this is strictly necessary. The spurious vector approach should work.
    // msr.write(APIC_BASE_MSR_REG, bootstrap_apic.base | (@as(u64, 1) << 11));

    // To enable the lapic, we set the sprious interrupt reg to 0xFF, and set the enable (8th bit) to 1
    bootstrap_apic.write(SPURIOUS_INT_REG, bootstrap_apic.read(SPURIOUS_INT_REG) | 0x100);
    bootstrap_apic.write(0x380, 0);

    terminal.print("lapic version 0x{x}\n", .{bootstrap_apic.read(VER_REG)});
}