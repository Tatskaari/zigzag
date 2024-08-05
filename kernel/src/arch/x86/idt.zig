const terminal = @import("drivers").terminal;

const IDTEntry = extern struct {
    isr_low: u16,
    kernel_cs: u16,
    ist: u8,
    flags: u8,
    isr_mid: u16,
    isr_high: u32,
    reserved: u32 = 0,
};

// Interrupt Descriptor Table Register:
const IDTR = packed struct(u80) {
    limit: u16,
    base: u64,
};

var idt: [256]IDTEntry = undefined;

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

pub const InterruptStackFrame = extern struct {
    eflags: u32,
    eip: u32,
    cs: u32,
    stack_pointer: u32,
    stack_segment: u32,
};

pub inline fn getCS() u16 {
    return asm volatile ("mov %cs, %[result]"
        : [result] "=r" (-> u16),
    );
}

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