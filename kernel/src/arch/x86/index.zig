pub const ports = @import("ports.zig");
pub const idt = @import("idt.zig");
pub const msr = @import("msr.zig");
pub const interupts = @import("interrupts.zig");
pub const madt = @import("madt.zig");
pub const pic = @import("pic.zig");
pub const lapic = @import("lapic.zig");

pub fn init() void {
    pic.disable();
    madt.init();
    lapic.init();
    interupts.init();
}