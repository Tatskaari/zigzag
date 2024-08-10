
const arch = @import("arch");
const kernel = @import("kernel");

// The Spurious Interrupt Vector used to catch any intrrupts we haven't handled
const APIC_BASE_MSR_REG = 0x1B;
const SPURIOUS_INT_REG = 0xF0;

const APIC = packed struct(usize) {
    base: usize,

    fn write(self: *APIC, reg: usize, value: u32) void {
        const val: *u32 = @ptrFromInt(self.base + reg);
        val.* = value;
    }

    fn read(self: *APIC, reg: usize) void {
        const val: *u32 = @ptrFromInt(self.base + reg);
        return val.*;
    }
};

fn get_lapic() APIC {
    // TODO cache these by cpu id
    return &APIC{.base = kernel.mem.physical_to_virtual(arch.msr.read(APIC_BASE_MSR_REG))};
}

fn init() void {
    // TODO iterate for each core somehwo
    const lapic = get_lapic();

    // To enable the lapic, we set the sprious interrupt reg to 0xFF which
    lapic.write(SPURIOUS_INT_REG, 0xFF);
}