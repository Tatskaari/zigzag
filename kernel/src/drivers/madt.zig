const kernel = @import("kernel");
const rsdt = @import("rsdt.zig");

const IO_APIC_TYPE = 1;

pub const DeviceListEntry = struct {
    type: u8,
    len: u8,
};

pub const IoApicEntry = struct {
    hdr: DeviceListEntry,
    id: u8,
    reserved: u8,
    addr: u32,
    global_system_interupt_base: u32,
};

pub const MADT = extern struct {
    header: rsdt.Header align(1),
    lapic_address: u32 align(1),
    flags: u32 align(1),

    pub fn local_apic_address(self: *MADT) usize {
        return kernel.mem.physical_to_virtual(@intCast(self.lapic_address));
    }

    pub fn find_device_entry_by_type(self: *MADT, t: u8) *DeviceListEntry {
        const entry: *DeviceListEntry = @ptrFromInt(@intFromPtr(&self.flags) + @sizeOf(u32));
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