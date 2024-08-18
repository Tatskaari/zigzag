const kernel = @import("kernel");
const terminal = @import("drivers").terminal;
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

    pub fn local_apic_address(self: *const MADT) usize {
        return kernel.mem.virtual_from_physical(@intCast(self.lapic_address));
    }

    pub fn find_device_entry_by_type(self: *const MADT, t: u8) *DeviceListEntry {
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

    pub fn get_io_apic_addr(self: *const MADT) usize {
        const entry = self.find_device_entry_by_type(IO_APIC_TYPE);
        const io_apic_entry : *IoApicEntry = @alignCast(@ptrCast(entry));
        return kernel.mem.virtual_from_physical(@intCast(io_apic_entry.addr));
    }

    pub fn print_apics(self: *const MADT) void {
        const end_addr = @intFromPtr(&self.header) + self.header.length;

        var entry: *DeviceListEntry = @ptrFromInt(@intFromPtr(&self.flags) + @sizeOf(u32));
        // There are 9 types. We don't need to loop unbounded here.
        while(true) {
            if(entry.type == 0) {
                const lapic_entry : *LocalApicEntry = @alignCast(@ptrCast(entry));
                terminal.print("found local apic in MADT: processor_id: {}, id: {}, virt addr: 0x{x}\n", .{lapic_entry.processor_id, lapic_entry.apic_id, kernel.mem.virtual_from_physical(self.lapic_address)});
            }

            if(entry.type == 1) {
                const io_apic_entry : *IoApicEntry = @alignCast(@ptrCast(entry));
                terminal.print("found io apic in MADT : id: {}, virt addr: 0x{x}\n", .{io_apic_entry.id, io_apic_entry.addr});
            }

            if(entry.type == 2) {
                const e : *SourceOverrideEntry = @alignCast(@ptrCast(entry));
                terminal.print("found interrupt source override in the MADT : bus: {}, irq: {}, global: {}\n", .{e.bus_source, e.irq_source, e.global_system_interrupt});
            }

            const entry_addr = @intFromPtr(entry) + entry.len;
            if (entry_addr >= end_addr) {
                break;
            }
            entry = @ptrFromInt(entry_addr);
        }
    }
};

pub var madt : *MADT = undefined;
pub var io_apic_addr : usize = undefined;

pub fn init() void {
    const hdr = rsdt.find_hdr(MADT_SIG) catch @panic("cound't find MADT header");
    madt = @alignCast(@ptrCast(hdr));
    io_apic_addr = madt.get_io_apic_addr();

    // For diagnostics
    madt.print_apics();
}