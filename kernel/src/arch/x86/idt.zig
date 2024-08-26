/// idt implements the interrupt descriptor table to load interrupt and exception handlers for various interrupt
/// requests

const cpu = @import("cpu.zig");

/// Vectors under this value are x86 architecture registers e.g. page fault, or div by zero. This vector, and anything
/// above are defined by this kernel.
pub const kernel_start_vector = 0x20;

var next_vector: u8 = kernel_start_vector;

/// IDTEntry is an entry in the interrupt descriptor table
pub const IDTEntry = packed struct {
    isr_low: u16, // first 16 bits of the function pointer
    kernel_cs: u16, // The code segment for the kernel. This should be whatever you set it to when you set this in the GDT.
    ist: u8 = 0, // Legacy nonense. Set this to 0.
    flags: Flags, // Sets the gate type, dpl, and p fields
    isr_mid: u16, // The next 16 bits of the function pointer
    isr_high: u32, // The last 32 bits of the function pointer
    reserved: u32 = 0,

    /// Flags is used to set the flags field above.
    pub const Flags = packed struct(u8) {
        kind: Kind,
        reserved: u1 = 0,
        ring: u2, // the ring the interupt executes in. This should be 0 in almost all cases.
        present: bool = true,
    };

    /// Traps allow interrupts to fire during the handler. We almost always want to use iterrupt.
    pub const Kind = enum(u4) {
        trap = 0xF,
        interrupt = 0xE,
    };
};

/// Interrupt Descriptor Table Register: used to tell the CPU about the location and legnth of the IDTEntry array below
const IDTR = packed struct(u80) {
    limit: u16,
    base: u64,
};

/// Interrupt Descriptor Table: the actual table that contains all the interrupt vectors to handle IRQs
var idt: [256]IDTEntry = undefined;

pub fn setDescriptor(vector: u8, isr: *const anyopaque, ring: u2, kind: IDTEntry.Kind) void {
    const isrPtr = @intFromPtr(isr);
    var entry = &idt[vector];

    entry.isr_low = @truncate(isrPtr & 0xFFFF);
    entry.isr_mid = @truncate((isrPtr >> 16) & 0xFFFF);
    entry.isr_high = @truncate(isrPtr >> 32);
    entry.kernel_cs = cpu.getCS();
    entry.flags = IDTEntry.Flags{
        .ring = ring,
        .kind = kind,
    };
}

// Represents the function signature of an interupt
const Interrupt = *const fn(state: *InterruptStackFrame) callconv(.Interrupt) void;

/// registerInterrupt adds an IDT entry for the given isr
pub fn registerInterrupt(comptime isr: Interrupt, ring: u2) u8 {
    const vec = getVector();
    setDescriptor(vec, isr, ring, IDTEntry.Kind.interrupt);
    return vec;
}

pub fn getVector() u8 {
    const vec = next_vector;
    next_vector += 1;
    return vec;
}

pub const InterruptStackFrame = extern struct {
    eflags: u32,
    eip: u32,
    cs: u32,
    stack_pointer: u32,
    stack_segment: u32,
};

pub fn load() void {
    const idtr = IDTR{ .base = @intFromPtr(&idt[0]), .limit = (@sizeOf(@TypeOf(idt))) - 1 };
    cpu.lidt(@bitCast(idtr));
}
