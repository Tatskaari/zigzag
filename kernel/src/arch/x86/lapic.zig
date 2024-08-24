const std = @import("std");

const hhdm = @import("kernel").services.mem.hhdm;
const kernel = @import("kernel");
const cpu = @import("cpu.zig");
const idt = @import("idt.zig");


const spurious_vec = 0xFF;

const apic_base_msr_reg = 0x1B;

const spurious_int_reg = 0xF0;
const task_priority_reg = 0x80;
const id_reg = 0x20;
const ver_reg = 0x30;
const eoi_reg = 0xB0;

const timer_lvt_reg = 0x320;
const initial_count_reg = 0x380;
const current_count_reg = 0x390;
const timer_div_reg = 0x3E0;

var lapic_ns_factor : u32 = undefined;
var calibrated = false;

pub const APIC = struct {
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
        self.write(initial_count_reg, 0);

        // This should have priority over any custom interupts.
        // self.write(task_priority_reg, idt.kernel_start_vector);
    }

    pub fn setTimerIsr(self: *const APIC, vec: u8, mode: TimerVec.Mode) void  {
        self.write(timer_lvt_reg, @bitCast(TimerVec{
            .vec = vec,
            .mode = mode,
        }));
    }

    pub fn setTimerNs(self: *const APIC, count: u32) void {
        self.write(initial_count_reg, count*lapic_ns_factor);
    }

    pub const TimerVec = packed struct(u32) {
        vec: u8, // the idt entry to trigger
        mask: bool = false, // If set to true, the interrupt is masked
        mode: Mode, // the mode (one shot, or periodic)
        reserved: u21 = 0,

        pub const Mode = enum(u2) {
            one_shot = 0b00,
            periodic = 0b01,
            tsc_deadline = 0b10,
        };
    };
};

// This is just a PoC to prove I can trigger and dispatch software interrupts
export fn spuriousIntISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Spurious interrupt! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
    while(true){}
}

pub fn getLapic() APIC {
    // TODO cache these by cpu id
    return APIC{.base = hhdm.virtualFromPhysical(cpu.msr.read(apic_base_msr_reg) & 0xFFFFF000)};
}

pub fn calibrate(timer: *kernel.services.timer.Timer) void {
    const calibration_ms = 10;

    getLapic().write(timer_lvt_reg, @bitCast(APIC.TimerVec{
        .vec = 0,
        .mask = true,     // Make sure the interrupt is masked... we don't actually want to trigger this.
        .mode = APIC.TimerVec.Mode.one_shot,
    }));

    const callback = struct {
        pub fn calibrationCallback(_: *anyopaque) void {
            const initial_count = getLapic().read(initial_count_reg);
            const current_count = getLapic().read(current_count_reg);

            lapic_ns_factor = @divFloor(initial_count - current_count, calibration_ms*1000);

            // reset the initial count. Probably not strictly necessary but is good practice.
            getLapic().write(initial_count_reg, 0);
            calibrated = true;

            kernel.debug.print("callibrated the apic to {} ticks per ns\n", .{lapic_ns_factor});
        }
    };

    getLapic().write(initial_count_reg, std.math.maxInt(u32));
    // Add a timer for 1ms from now, so we can see how many ticks the lapic has in that time.
    timer.add_timer(calibration_ms, false, .{
        .func = &callback.calibrationCallback,
    });
    
    while (!calibrated) {}
}

pub fn init() void {
    // TODO for each CPU once we enter MP
    getLapic().enable();
    idt.setDescriptor(spurious_vec, &spuriousIntISR, 0, idt.IDTEntry.Kind.interrupt);
}