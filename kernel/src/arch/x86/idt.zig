const IDTEntry = packed struct {
    isr_low: u16, // first 16 bits of the function pointer
    kernel_cs: u16, // The code segment for the kernel. This should be whatever you set it to when you set this in the GDT.
    ist: u8 = 0, // Legacy nonense. Set this to 0.
    flags: u8, // Sets the gate type, dpl, and p fields
    isr_mid: u16, // The next 16 bits of the function pointer
    isr_high: u32, // The last 32 bits of the function pointer
    reserved: u32 = 0,
};

// Interrupt Descriptor Table Register
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
}

pub const InterruptStackFrame = extern struct {
    eflags: u32,
    eip: u32,
    cs: u32,
    stack_pointer: u32,
    stack_segment: u32,
};

// TODO set this explicitly in the GDT ourselves
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