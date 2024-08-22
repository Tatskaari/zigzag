const idt = @import("idt.zig");
const print = @import("kernel").drivers.terminal.print;
const lapic = @import("lapic.zig");

export fn divErrISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("Div by zero! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn debugISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("Debug interupt! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
}

export fn nonMaskableISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("Non-maskable interupt! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn breakpointISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("Breakpoint interupt! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
}

export fn overflowISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("Overflow error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn boundRangeExceededISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("Bound range exceeded error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn invalidOpcodeISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("Invalid op code! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn deviceNotAvailableISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("Device not available error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn doubleFaultISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("Double fault! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn invalidTSSISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("Ivalid TSS error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn segmentNotPresentISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("Segment not present error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn stackSegFaultISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("Seg fault! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn gpaFaultISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("GPA fault! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn pageFaultISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("Page fault! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn fpuErrISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("FPU error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

export fn alignCheckISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("Align check (not handled)! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
}

export fn machineCheckISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("Machine check (not handled)! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
}

export fn simdErrISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("SIMD error! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}


// This is just a PoC to prove I can trigger and dispatch software interrupts
export fn spuriousIntISR(state: *idt.InterruptStackFrame) callconv(.Interrupt) void {
    print("Spurious interrupt! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});
    while(true){}
}

pub fn enable() void {
    asm volatile ("sti");
}

// Sets up the basic CPU intrupts
pub fn init() void {
    idt.setDescriptor(0, @intFromPtr(&divErrISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(1, @intFromPtr(&debugISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(2, @intFromPtr(&nonMaskableISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(3, @intFromPtr(&breakpointISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(4, @intFromPtr(&overflowISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(5, @intFromPtr(&boundRangeExceededISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(6, @intFromPtr(&invalidOpcodeISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(7, @intFromPtr(&deviceNotAvailableISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(8, @intFromPtr(&doubleFaultISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(10, @intFromPtr(&invalidTSSISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(11, @intFromPtr(&segmentNotPresentISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(12, @intFromPtr(&stackSegFaultISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(13, @intFromPtr(&gpaFaultISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(14, @intFromPtr(&pageFaultISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(16, @intFromPtr(&fpuErrISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(17, @intFromPtr(&alignCheckISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(18, @intFromPtr(&machineCheckISR), 0, idt.IDTEntry.Kind.interrupt);
    idt.setDescriptor(19, @intFromPtr(&simdErrISR), 0, idt.IDTEntry.Kind.interrupt);


    // TODO this might make more sense being set from the lapic setup code
    idt.setDescriptor(0xFF, @intFromPtr(&spuriousIntISR), 0, idt.IDTEntry.Kind.interrupt);

    idt.load();
}