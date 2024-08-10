The IDT is a data structure that essentially contains a table of memory addresses that execution can jump to to handle [[Interrupts on x86]]. 

This should be set up, otherwise when we encounter faults, the system will crash and not handle the error, which can make it very difficult to figure out what went wrong. 

## Overview
To set up the IDT, you must perform the following steps:

- Write a number of interrupt request handlers for the various types of interrupts x86 might throw, plus any other custom interrupts you may have
- Load these into memory e.g. as a `[MAX_IDT_SIZE]IDTEntry` variable
- Create an IDTR (interrupt descriptor table reference) and load this with the `lidt` instruction 

## Table structure 

Each entry in the table has the following structure:
```zig
var idt: [256]IDTEntry = undefined;

const IDTEntry = packed struct {  
    isr_low: u16, // first 16 bits of the function pointer  
    kernel_cs: u16, // The code segment for the kernel. This should be whatever you set it to when you set this in the GDT.  
    ist: u8 = 0, // Legacy nonense. Set this to 0.  
    flags: u8, // Sets the gate type, dpl, and p fields  
    isr_mid: u16, // The next 16 bits of the function pointer  
    isr_high: u32, // The last 32 bits of the function pointer  
    reserved: u32 = 0,  
};

pub fn setDescriptor(vector: usize, isrPtr: usize, dpl: u8) void {  
    var entry = &idt[vector];  
  
    entry.isr_low = @truncate(isrPtr & 0xFFFF);  
    entry.isr_mid = @truncate((isrPtr >> 16) & 0xFFFF);  
    entry.isr_high = @truncate(isrPtr >> 32);  
    //your code selector may be different!  
    entry.kernel_cs = getCS();  
    //trap gate + present + DPL  
    entry.flags = 0b1110 | ((dpl & 0b11) << 5) | (1 << 7);  
    //ist disabled  
    entry.ist = 0;  
}
```

The table can be as long as you like e.g. 256 entries.

## Setting descriptors
Descriptors should use the interrupt calling convention. This is important so they don't clobber registers on the CPU that are used to pass information about what interrupt triggered.

The stack frame for an interrupt is as follows on a 64 bit machine:
```zig
pub const InterruptStackFrame = extern struct {  
    eflags: u32,  
    eip: u32,  
    cs: u32,  
    stack_pointer: u32,  
    stack_segment: u32,  
};

export fn divErrISR(state: *InterruptStackFrame) callconv(.Interrupt) void {  
    terminal.print("Div by zero! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});  
    while(true){}  
}

fn init() {
	setDescriptor(0, @intFromPtr(&divErrISR), 0);
}
```

NB: you may wish to wrap the interrupt in some custom assembly to include additional information in the interrupt stack, but this is probably good enough for now. 



TODO look into what the dpl field and traps means
## Loading the IDT 

Once you have loaded all your interrupt descriptors into your table, you need to load them using the `lidt` instruction:
```
pub fn load() void {  
    const idtr = IDTR{  
        .base = @intFromPtr(&idt[0]),  
        .limit = (@sizeOf(@TypeOf(idt))) - 1  
    };  
  
    asm volatile ("lidt %[p]"  
        :  
        : [p] "*p" (&idtr),  
    );  
}
```

The full IDT initialization would look something like:
```
export fn divErrISR(state: *InterruptStackFrame) callconv(.Interrupt) void {  
    terminal.print("Div by zero! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});  
    while(true){}  
}
...

export fn customInterupt(state: *InterruptStackFrame) callconv(.Interrupt) void {  
    terminal.print("Custom interrupt called! eip: 0x{x}, cs: 0x{x}, eflags: 0x{x}\n", .{state.eip, state.cs, state.eflags});  
    while(true){}  
}

// Sets up the basic CPU intrupts  
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
  
    arch.idt.setDescriptor(0x10, @intFromPtr(&customInterupt), 0);  
  
    arch.idt.load();  
}
```

And you can test this with:

```
asm volatile ("int $0x10");
```

Which should call the custom interrupt above!