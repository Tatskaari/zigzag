const arch = @import("arch");
const terminal = @import("terminal.zig");

const DATA_REG = 0x60;
const STATUS_REG = 0x64;
const COMMAND_REG = STATUS_REG;

const DISABLE_PORT_1 = 0xAD;
const ENABLE_PORT_1 = DISABLE_PORT_1 + 0x01;
const DISABLE_PORT_2 = 0xA7;
const ENABLE_PORT_2 = DISABLE_PORT_2 + 0x01;

// The ps/2 keyboard is connected to port 1 of the IO apic
const IOAPIC_ENTRY_NUM = 1;
// We can choose whatever we want
const IDT_VECTOR = 0x20;

export fn keyboard_isr(_: *arch.idt.InterruptStackFrame) callconv(.Interrupt) void {
    const scancode = arch.ports.inb(DATA_REG);
    terminal.print("Scancode read: 0x{x}\n", .{scancode});
    arch.lapic.get_lapic().end();
}

pub fn enable() void {
    arch.ports.outb(COMMAND_REG, ENABLE_PORT_1);
    arch.ports.outb(COMMAND_REG, ENABLE_PORT_2);
}

pub fn disable() void {
    arch.ports.outb(COMMAND_REG, DISABLE_PORT_1);
    arch.ports.outb(COMMAND_REG, DISABLE_PORT_2);
}

fn init_redtbl() void {
    var entry = arch.ioapic.apic.read_redirect_entry(IOAPIC_ENTRY_NUM);
    terminal.print("entry mask {}\n", .{entry.mask});
    entry.mask = false;
    entry.vector = IDT_VECTOR;
    entry.destination_mode = arch.ioapic.DestinationMode.physical;
    entry.destination = @truncate(arch.lapic.get_lapic().get_id());
    arch.ioapic.apic.write_redirect_entry(IOAPIC_ENTRY_NUM, entry);
}

pub fn init() void {
    // 1. Set up the redtable entries on the io apic to call the isr above on the current local apic
    init_redtbl();

    // 2. Register the isr at the right vector
    arch.idt.setDescriptor(IDT_VECTOR, @intFromPtr(&keyboard_isr), 0x8E);

    // 3. Determine/check which scan lines we're going to use
    // TODO set up the type of scan codes we're going to use here

    // 4. enable the PS/2 keyboard
    enable();
}