const kernel = @import("kernel");
const rsdt = @import("rsdt.zig");

const MADT_SIG: [4]u8 = [4]u8{'A', 'P', 'I', 'C'};
const IO_APIC_TYPE = 1;

pub const DeviceListEntry = extern struct {
    type: u8 align(1),
    len: u8 align(1),
};

pub const IoApicEntry = extern struct {
    hdr: DeviceListEntry align(1),
    id: u8 align(1),
    reserved: u8 align(1),
    addr: u32 align(1),
    global_system_interupt_base: u32 align(1),
};

pub const MADT = extern struct {
    header: rsdt.Header align(1),
    lapic_address: u32 align(1),
    flags: u32 align(1),

    pub fn local_apic_address(self: *MADT) usize {
        return kernel.mem.physical_to_virtual(@intCast(self.lapic_address));
    }

    pub fn find_device_entry_by_type(self: *MADT, t: u8) *DeviceListEntry {
        var entry: *DeviceListEntry = @ptrFromInt(@intFromPtr(&self.flags) + @sizeOf(u32));
        // There are 9 types. We don't need to loop unbounded here.
        for(0..9) |_| {
            if (entry.type == t) {
                return entry;
            } else {
                entry = @ptrFromInt(@intFromPtr(entry) + entry.len);
            }
        }
        // TODO include the type in the error message once we have an allocator
        @panic("coun't find entry by type");
    }

    pub fn get_io_apic_addr(self: *MADT) usize {
        const entry = self.find_device_entry_by_type(IO_APIC_TYPE);
        const io_apic_entry : *IoApicEntry = @alignCast(@ptrCast(entry));
        return kernel.mem.physical_to_virtual(@intCast(io_apic_entry.addr));
    }
};

pub var madt : *MADT = undefined;
pub var io_apic_addr : usize = undefined;

pub fn init() void {
    const hdr = rsdt.find_hdr(MADT_SIG) catch @panic("cound't find MADT header");
    madt = @alignCast(@ptrCast(hdr));
    io_apic_addr = madt.get_io_apic_addr();
}