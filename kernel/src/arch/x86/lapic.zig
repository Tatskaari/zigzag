const kernel = @import("kernel");
const terminal = @import("drivers").terminal;
const msr = @import("msr.zig");

const APIC_BASE_MSR_REG = 0x1B;
const SPURIOUS_INT_REG = 0xF0;

const ID_REG = 0x20;
const VER_REG = 0x30;

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
        terminal.print("lapic id: {}\n", .{id});
        return id;
    }
};

pub fn get_lapic() APIC {
    // TODO cache these by cpu id
    return APIC{.base = kernel.mem.physical_to_virtual(msr.read(APIC_BASE_MSR_REG) & 0xFFFFF000)};
}

pub fn init() void {
    // TODO init for each core somehwo
    const lapic = get_lapic();

    // To enable the lapic, we set the sprious interrupt reg to 0xFF which
    lapic.write(SPURIOUS_INT_REG, 0xFF | 0x100);

    terminal.print("lapic version 0x{x}\n", .{lapic.read(VER_REG)});
}