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

pub fn setDescriptor(vector: u8, comptime isr: Interrupt, ring: u2, kind: IDTEntry.Kind) void {
    const isrPtr = wrapCall(isr);

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
const Interrupt = *const fn(*cpu.Context) callconv(.C) void;

// wrapCall will wrap the interrupt in C calling convention in a naked function that pushes the CPU context to the stack
//
// This code is heavily inspired (stolen?) by the wrapper here:
// https://github.com/yhyadev/yos/blob/master/src/kernel/arch/x86_64/cpu.zig#L192
pub fn wrapCall(comptime isr: Interrupt) usize {
    const closure = struct {
        pub fn wrapper() callconv(.Naked) void {
            asm volatile (
                // Push the CPU state to the stack in reverse order to how they're defined in cpu.Context
                \\ push %rbp
                \\ push %rax
                \\ push %rbx
                \\ push %rcx
                \\ push %rdx
                \\ push %rdi
                \\ push %rsi
                \\ push %r8
                \\ push %r9
                \\ push %r10
                \\ push %r11
                \\ push %r12
                \\ push %r13
                \\ push %r14
                \\ push %r15
                \\ mov %ds, %rax
                \\ push %rax
                \\ mov %es, %rax
                \\ push %rax
                \\ mov $0x10, %ax
                \\ mov %ax, %ds
                \\ mov %ax, %es
                \\ cld
            );

            // TODO it would be better to have a different version of this that allows us to return the iret frame.
            // Put a pointer to the above context on the stack frame and call the function
            asm volatile (
                \\ mov %rsp, %rdi
                \\ call *%[isr]
                :: [isr] "{rax}" (isr),
            );

            // Restore CPU state and return
            asm volatile (
                \\ pop %rax
                \\ mov %rax, %es
                \\ pop %rax
                \\ mov %rax, %ds
                \\ pop %r15
                \\ pop %r14
                \\ pop %r13
                \\ pop %r12
                \\ pop %r11
                \\ pop %r10
                \\ pop %r9
                \\ pop %r8
                \\ pop %rsi
                \\ pop %rdi
                \\ pop %rdx
                \\ pop %rcx
                \\ pop %rbx
                \\ pop %rax
                \\ pop %rbp
                \\ iretq
            );
        }
    };
    return @intFromPtr(&closure.wrapper);
}

/// registerInterrupt adds an IDT entry for the given isr
pub fn registerInterrupt(comptime isr: Interrupt, ring: u2) u8 {
    const vec = next_vector;
    setDescriptor(vec, isr, ring, IDTEntry.Kind.interrupt);
    next_vector += 1;
    return vec;
}

pub const InterruptStackFrame = cpu.Context;

pub fn load() void {
    const idtr = IDTR{ .base = @intFromPtr(&idt[0]), .limit = (@sizeOf(@TypeOf(idt))) - 1 };
    cpu.lidt(@bitCast(idtr));
}
