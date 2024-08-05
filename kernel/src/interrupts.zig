const arch = @import("arch");
const terminal = @import("drivers").terminal;

export fn divErrISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("Div by zero! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn debugISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("Debug interupt! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
}

export fn nonMaskableISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("Non-maskable interupt! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn breakpointISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("Breakpoint interupt! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
}

export fn overflowISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("Overflow error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn boundRangeExceededISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("Bound range exceeded error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn invalidOpcodeISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("Invalid op code! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn deviceNotAvailableISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("Device not available error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn doubleFaultISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("Double fault! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn invalidTSSISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("Ivalid TSS error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn segmentNotPresentISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("Segment not present error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn stackSegFaultISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("Seg fault! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn gpaFaultISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("GPA fault! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn pageFaultISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("Page fault! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn fpuErrISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("FPU error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn alignCheckISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("Align check (not handled)! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
}

export fn machineCheckISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("Machine check (not handled)! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
}

export fn simdErrISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("SIMD error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

// This is just a PoC to prove I can trigger and dispatch software interrupts
export fn customISR(state: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    terminal.print("Custom! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
}

pub fn init() void {
    arch.idt.setDescriptor(0, @intFromPtr(&divErrISR), 0);
    arch.idt.setDescriptor(1, @intFromPtr(&debugISR), 0);
    arch.idt.setDescriptor(2, @intFromPtr(&nonMaskableISR), 0);
    arch.idt.setDescriptor(3, @intFromPtr(&breakpointISR), 0);
    arch.idt.setDescriptor(4, @intFromPtr(&overflowISR), 0);
    arch.idt.setDescriptor(5, @intFromPtr(&boundRangeExceededISR), 0);
    arch.idt.setDescriptor(6, @intFromPtr(&invalidOpcodeISR), 0);
    arch.idt.setDescriptor(7, @intFromPtr(&deviceNotAvailableISR), 0);
    arch.idt.setDescriptor(8, @intFromPtr(&doubleFaultISR), 0);
    arch.idt.setDescriptor(10, @intFromPtr(&invalidTSSISR), 0);
    arch.idt.setDescriptor(11, @intFromPtr(&segmentNotPresentISR), 0);
    arch.idt.setDescriptor(12, @intFromPtr(&stackSegFaultISR), 0);
    arch.idt.setDescriptor(13, @intFromPtr(&gpaFaultISR), 0);
    arch.idt.setDescriptor(14, @intFromPtr(&pageFaultISR), 0);
    arch.idt.setDescriptor(16, @intFromPtr(&fpuErrISR), 0);
    arch.idt.setDescriptor(17, @intFromPtr(&alignCheckISR), 0);
    arch.idt.setDescriptor(18, @intFromPtr(&machineCheckISR), 0);
    arch.idt.setDescriptor(19, @intFromPtr(&simdErrISR), 0);

    // Just 'cus we can
    arch.idt.setDescriptor(0x10, @intFromPtr(&customISR), 0x8E);

    arch.idt.load();
}