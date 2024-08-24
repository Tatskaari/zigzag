const hhdm = @import("kernel").services.mem.hhdm;
const kernel = @import("kernel");
const cpu = @import("cpu.zig");
const idt = @import("idt.zig");

const apic_base_msr_reg = 0x1B;
const spurious_int_reg = 0xF0;
const spurious_vec = 0xFF;

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
    }
};

// This is just a PoC to prove I can trigger and dispatch software interrupts
export fn spuriousIntISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Spurious interrupt! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
    while(true){}
}


pub fn get_lapic() APIC {
    // TODO cache these by cpu id
    return APIC{.base = hhdm.virtualFromPhysical(cpu.msr.read(apic_base_msr_reg) & 0xFFFFF000)};
}

pub fn init() void {
    // TODO for each CPU once we enter MP
    get_lapic().enable();
    idt.setDescriptor(spurious_vec, &spuriousIntISR, 0, idt.IDTEntry.Kind.interrupt);
}