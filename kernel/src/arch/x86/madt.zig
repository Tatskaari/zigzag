const services = @import("kernel").services;
const kernel = @import("kernel");
const rsdt = @import("../rsdt.zig");

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

pub const LocalApicEntry = extern struct {
    hdr: DeviceListEntry align(1),
    processor_id: u8 align(1),
    apic_id: u8 align(1),
    flags: u32 align(1),
};

pub const SourceOverrideEntry = extern struct {
    hdr: DeviceListEntry align(1),
    bus_source: u8 align(1),
    irq_source: u8 align(1),
    global_system_interrupt: u32 align(1),
    flags: u16 align(1),
};

pub const MADT = extern struct {
    header: rsdt.Header align(1),
    lapic_address: u32 align(1),
    flags: u32 align(1),

    pub fn localApicAddress(self: *const MADT) usize {
        return services.mem.hhdm.virtualFromPhysical(@intCast(self.lapic_address));
    }

    pub fn findDeviceEntryByType(self: *const MADT, t: u8) *DeviceListEntry {
        const end_addr = @intFromPtr(&self.header) + self.header.length;
        var entry: *DeviceListEntry = @ptrFromInt(@intFromPtr(&self.flags) + @sizeOf(u32));
        // There are 9 types. We don't need to loop unbounded here.
        while(true) {
            if (entry.type == t) {
                return entry;
            } else {
                const entry_addr = @intFromPtr(entry) + entry.len;
                if (entry_addr >= end_addr) {
                    @panic("coun't find entry by type");
                }
                entry = @ptrFromInt(entry_addr);
            }
        }
    }

    pub fn getIoApicAddress(self: *const MADT) usize {
        const entry = self.findDeviceEntryByType(IO_APIC_TYPE);
        const io_apic_entry : *IoApicEntry = @alignCast(@ptrCast(entry));
        return services.mem.hhdm.virtualFromPhysical(@intCast(io_apic_entry.addr));
    }

    pub fn printApics(self: *const MADT) void {
        const end_addr = @intFromPtr(&self.header) + self.header.length;

        var entry: *DeviceListEntry = @ptrFromInt(@intFromPtr(&self.flags) + @sizeOf(u32));
        // There are 9 types. We don't need to loop unbounded here.
        while(true) {
            if(entry.type == 0) {
                const lapic_entry : *LocalApicEntry = @alignCast(@ptrCast(entry));
                kernel.debug.print("found local apic in MADT: processor_id: {}, id: {}, virt addr: 0x{x}\n", .{lapic_entry.processor_id, lapic_entry.apic_id, services.mem.hhdm.virtualFromPhysical(self.lapic_address)});
            }

            if(entry.type == 1) {
                const io_apic_entry : *IoApicEntry = @alignCast(@ptrCast(entry));
                kernel.debug.print("found io apic in MADT : id: {}, virt addr: 0x{x}\n", .{io_apic_entry.id, io_apic_entry.addr});
            }

            if(entry.type == 2) {
                const e : *SourceOverrideEntry = @alignCast(@ptrCast(entry));
                kernel.debug.print("found interrupt source override in the MADT : bus: {}, irq: {}, global: {}\n", .{e.bus_source, e.irq_source, e.global_system_interrupt});
            }

            const entry_addr = @intFromPtr(entry) + entry.len;
            if (entry_addr >= end_addr) {
                break;
            }
            entry = @ptrFromInt(entry_addr);
        }
    }
};

pub var io_apic_addr : usize = undefined;

pub fn getMadt(dt: *rsdt.RSDT) *MADT {
    const hdr = dt.findHdr(MADT_SIG) catch @panic("cound't find MADT header");
    return @alignCast(@ptrCast(hdr));
}