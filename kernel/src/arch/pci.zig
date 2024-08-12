const std = @import("std");
const arch = @import("index.zig");
const terminal = @import("drivers").terminal;
// THese are teh ports that PCI uses to enable software to read the PCI config
const PCI_CONFIG_ADDRESS = 0xCF8;
const PCI_CONFIG_DATA = 0xCFC;

const INVALID_VENDOR = 0xFFFF;

const Class = enum(u8) {
    Unclassified,
    MassStorage,
    Network,
    Display,
    Multimedia,
    Memory,
    Bridge,
    _
};

pub const PciAddress = packed struct {
    offset: u8,
    function: u3,
    slot: u5,
    bus: u8,
    reserved: u7,
    enable: u1,
};

fn format_class(class: u8) [*:0]const u8 {
    const c : Class = @enumFromInt(class);
    switch (c) {
        Class.Unclassified,
        Class.MassStorage,
        Class.Network,
        Class.Display,
        Class.Multimedia,
        Class.Bridge,
        Class.Memory => {
            return @tagName(c);
        },
        _ => return "Unknown",
    }
}

//     0               8               16              24             32
//     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// 0x0 |           vendor ID           |           device ID           |
//     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// 0x4 |            command            |             status            |
//     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// 0x8 |  revision ID  |    prog IF    |    subclass   |     class     |
//     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// 0xC |cache line size| latency timer |   header type |      bist     |
//     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
const Offset = enum (u8) {
    DeviceID = 0x0,
    VendorID = 0x2,
    Status = 0x4,
    Command = 0x6,
    RevisionID = 0x8,
    ProgIF = 0x9,
    Subclass = 0xA,
    Class = 0xB,
    CacheLineSize = 0xC,
    LatencyTimer = 0xD,
    HeaderType = 0xE,
    Bist = 0xF,
};

pub const PciDevice = struct {
    bus: u8,
    slot: u5,
    function: u3,

    pub fn address(self: PciDevice, offset: u8) PciAddress {
        return PciAddress{
            .enable = 1,
            .reserved = 0,
            .bus = self.bus,
            .slot = self.slot,
            .function = self.function,
            .offset = offset,
        };
    }

    pub fn is_empty(self: PciDevice) bool {
        return self.vendor_id() == INVALID_VENDOR;
    }

    // Common headers
    pub fn vendor_id(self: PciDevice) u16 {
        return self.config_read(u16, @intFromEnum(Offset.VendorID));
    }

    pub fn device(self: PciDevice) u16 {
        return self.config_read(u16, @intFromEnum(Offset.DeviceID));
    }
    pub fn subclass(self: PciDevice) u8 {
        return self.config_read(u8, @intFromEnum(Offset.Subclass));
    }
    pub fn class(self: PciDevice) u8 {
        return self.config_read(u8, @intFromEnum(Offset.Class));
    }
    pub fn header_type(self: PciDevice) u8 {
        return self.config_read(u8, @intFromEnum(Offset.HeaderType));
    }

    pub fn intr_line(self: PciDevice) u8 {
        return self.config_read(u8, 0x3c);
    }
    pub fn bar(self: PciDevice, n: usize) u32 {
        return self.config_read(u32, 0x10 + 4 * n);
    }
    // only for header_type == 0
    pub fn subsystem(self: PciDevice) u16 {
        return self.config_read(u8, 0x2e);
    }

    pub fn format(self: PciDevice) void {
        const slot : u8 = @intCast(self.slot);
        const function : u8 = @intCast(self.function);

        terminal.print("Bus {}, slot {}, function {}: ", .{self.bus, slot, function});
        terminal.print(" class: {s}, subclass: {}, vendor id: {}\n", .{format_class(self.class()), self.subclass(), self.vendor_id()});
    }

    pub inline fn config_read(self: PciDevice, comptime size: type, offset: u8) size {
        // ask for access before reading config
        arch.ports.outl(PCI_CONFIG_ADDRESS, @bitCast(self.address(offset)));
        switch (size) {
        // read the correct size
            u8 => return arch.ports.inb(PCI_CONFIG_DATA),
            u16 => return arch.ports.inw(PCI_CONFIG_DATA),
            u32 => return arch.ports.inl(PCI_CONFIG_DATA),
            else => @compileError("pci only support reading up to 32 bits"),
        }
    }
};

pub fn device(bus: u8, slot: u5, function: u3) PciDevice {
    return PciDevice{ .bus = bus, .slot = slot, .function = function };
}

pub fn lspci() void {
    for (0..32) |slot| {
        for (0..8) |function | {
            const dev = device(0, @intCast(slot), @intCast(function));
            if (dev.is_empty()) {
                continue;
            }
            dev.format();
        }
    }
}
