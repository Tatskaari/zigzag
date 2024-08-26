const idt = @import("idt.zig");
const cpu = @import("cpu.zig");
const kernel = @import("kernel");
const lapic = @import("lapic.zig");

export fn divErrISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Div by zero! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
    while(true){}
}

export fn debugISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Debug interupt! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
}

export fn nonMaskableISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Non-maskable interupt! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
    while(true){}
}

export fn breakpointISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Breakpoint interupt! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
}

export fn overflowISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Overflow error! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
    while(true){}
}

export fn boundRangeExceededISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Bound range exceeded error! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
    while(true){}
}

export fn invalidOpcodeISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Invalid op code! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
    while(true){}
}

export fn deviceNotAvailableISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Device not available error! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
    while(true){}
}

export fn doubleFaultISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Double fault! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
    while(true){}
}

export fn invalidTSSISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Ivalid TSS error! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
    while(true){}
}

export fn segmentNotPresentISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Segment not present error! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
    while(true){}
}

export fn stackSegFaultISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Seg fault! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
    while(true){}
}

export fn gpaFaultISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("GPA fault! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
    while(true){}
}

export fn pageFaultISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Page fault! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
    while(true){}
}

export fn fpuErrISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("FPU error! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
    while(true){}
}

export fn alignCheckISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Align check (not handled)! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
}

export fn machineCheckISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("Machine check (not handled)! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
}

export fn simdErrISR(state: *cpu.Context) callconv(.C) void {
    kernel.debug.print("SIMD error! rip: 0x{x}, cs: 0x{x}, rflags: 0x{x}\n", .{state.rip, state.cs, state.rflags});
    while(true){}
}

pub fn enable() void {
    asm volatile ("sti");
}

pub inline fn disable() void {
    asm volatile ("cli");
}

// Sets up the basic CPU intrupts
pub fn init() void {
    idt.setDescriptor(0, &divErrISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(1, &debugISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(2, &nonMaskableISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(3, &breakpointISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(4, &overflowISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(5, &boundRangeExceededISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(6, &invalidOpcodeISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(7, &deviceNotAvailableISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(8, &doubleFaultISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(10, &invalidTSSISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(11, &segmentNotPresentISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(12, &stackSegFaultISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(13, &gpaFaultISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(14, &pageFaultISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(16, &fpuErrISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(17, &alignCheckISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(18, &machineCheckISR, 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(19, &simdErrISR, 0, idt.IDTEntry.Kind.interrupt);

    idt.load();
}