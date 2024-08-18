pub const ports = @import("ports.zig");
pub const idt = @import("idt.zig");
pub const cpu = @import("cpu/index.zig");
pub const interupts = @import("interrupts.zig");
pub const madt = @import("madt.zig");
pub const pic = @import("pic.zig");
pub const lapic = @import("lapic.zig");
pub const ioapic = @import("ioapic.zig");
pub const paging = @import("paging.zig");

pub fn init() void {
    pic.disable();
    interupts.init();
    madt.init();
    ioapic.init();
    lapic.init();
}