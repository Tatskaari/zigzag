const idt = @import("idt.zig");
const kernel = @import("kernel");
const lapic = @import("lapic.zig");

export fn divErrISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("Div by zero! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn debugISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("Debug interupt! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
}

export fn nonMaskableISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("Non-maskable interupt! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn breakpointISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("Breakpoint interupt! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
}

export fn overflowISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("Overflow error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn boundRangeExceededISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("Bound range exceeded error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn invalidOpcodeISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("Invalid op code! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn deviceNotAvailableISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("Device not available error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn doubleFaultISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("Double fault! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn invalidTSSISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("Ivalid TSS error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn segmentNotPresentISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("Segment not present error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn stackSegFaultISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("Seg fault! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn gpaFaultISR(_: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("GPA fault!\n", .{});
    while(true){}
}

export fn pageFaultISR(_: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("Page fault! eip\n", .{});
    while(true){}
}

export fn fpuErrISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("FPU error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn alignCheckISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("Align check (not handled)! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
}

export fn machineCheckISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("Machine check (not handled)! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
}

export fn simdErrISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    kernel.debug.print("SIMD error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

pub fn enable() void {
    asm volatile ("sti");
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