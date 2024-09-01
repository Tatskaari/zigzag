const std = @import("std");
const arch = @import("index.zig");
const kernel = @import("kernel");
// THese are teh ports that PCI uses to enable software to read the PCI config
const pci_config_address = 0xCF8;
const pci_config_data = 0xCFC;

const config_bar_offset = 0x10;

const invalid_vendor = 0xFFFF;

// VirtIO vendors are always this value
pub const virtio_vendor_id = 0x1AF4;

// VirtIO device IDs must be between this range
pub const virtio_device_id_start = 0x1000;
pub const virtio_device_id_end = 0x103F;

pub const Class = enum(u8) { Unclassified, MassStorage, Network, Display, Multimedia, Memory, Bridge, _ };

pub const MassstorageSubclasses = enum(u8) {
    Scsi,
    Ide,
    Floppy,
    IpiBus,
    Raid,
    Ata,
    Sata,
    SaScsi,
    Nvm,
    Other = 0x80,
};

pub const PciAddress = packed struct {
    offset: u8,
    function: u3,
    slot: u5,
    bus: u8,
    reserved: u7,
    enable: u1,
};

fn formatClass(class: u8) [*:0]const u8 {
    const c: Class = @enumFromInt(class);
    switch (c) {
        Class.Unclassified, Class.MassStorage, Class.Network, Class.Display, Class.Multimedia, Class.Bridge, Class.Memory => {
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
const Offset = enum(u8) {
    VendorID = 0x0,
    DeviceID = 0x2,
    Command = 0x4,
    Status = 0x6,
    RevisionID = 0x8,
    ProgIF = 0x9,
    Subclass = 0xA,
    Class = 0xB,
    CacheLineSize = 0xC,
    LatencyTimer = 0xD,
    HeaderType = 0xE,
    Bist = 0xF,
};

const CommonHeaderZeroOffsets = enum(u8) {
    SubsystemID = 0x2C,
};

/// BaseAddressRegister represents the base address of a PCI device.
pub const BaseAddressRegister = struct {
    // Whether this address is an io address or a memory address
    isIoMapped: bool,
    isPrefetchable: bool, // Only relevant for memory mapped
    address: usize,
};

pub const HeaderTypeResponse = packed struct(u8) {
    type: u7,
    is_multi_function: bool,
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

    pub fn isEmpty(self: PciDevice) bool {
        return self.vendorId() == invalid_vendor;
    }

    // Common headers
    pub fn vendorId(self: PciDevice) u16 {
        return self.configRead(u16, @intFromEnum(Offset.VendorID));
    }

    pub fn deviceId(self: PciDevice) u16 {
        return self.configRead(u16, @intFromEnum(Offset.DeviceID));
    }
    pub fn subclass(self: PciDevice) u8 {
        return self.configRead(u8, @intFromEnum(Offset.Subclass));
    }
    pub fn class(self: PciDevice) u8 {
        return self.configRead(u8, @intFromEnum(Offset.Class));
    }
    pub fn headerType(self: PciDevice) HeaderTypeResponse {
        return @bitCast(self.configRead(u8, @intFromEnum(Offset.HeaderType)));
    }

    pub fn subsystemID(self: PciDevice) u16 {
        return self.configRead(u16, CommonHeaderZeroOffsets.SubsystemID);
    }

    pub fn intrLine(self: PciDevice) u8 {
        return self.configRead(u8, 0x3c);
    }
    
    pub fn baseAddressReg(self: PciDevice, n: u8) BaseAddressRegister {
        const resp: BarResponse = @bitCast(self.configRead(u32, config_bar_offset + n*@sizeOf(u32)));
        var ret = BaseAddressRegister{
            .is_io_mapped = resp.is_io_mapped,
            .address = resp.address,
        };

        if(!resp.is_io_mapped) {
            ret.isPrefetchable = resp.memoryMapped().prefetchable;
        }

        // Check if we're fetching a wide memory mapped address.
        if(resp.is_io_mapped or resp.memoryMapped().type == BarResponse.Mem.Type.Small) {
            return resp;
        }

        const address_lo = self.configRead(u32, config_bar_offset + (n+1)*@sizeOf(u32));
        ret.address = (ret.address << 32) + address_lo;

        if(!ret.isIoMapped) {
            ret.address = kernel.services.mem.hhdm.virtualFromPhysical(ret.address);
        }
        return ret;
    }

    // only for header_type == 0
    pub fn subsystem(self: PciDevice) u16 {
        return self.configRead(u8, 0x2e);
    }

    pub fn format(self: PciDevice) void {
        const slot: u8 = @intCast(self.slot);
        const function: u8 = @intCast(self.function);

        kernel.debug.print("Bus {}, slot {}, function {}: ", .{ self.bus, slot, function });
        kernel.debug.print(" class: {s}, subclass: {}, device id: 0x{x} vendor id: 0x{x} hdr_type {}|{}\n", .{ formatClass(self.class()), self.subclass(), self.deviceId(), self.vendorId(), self.headerType().type, self.headerType().is_multi_function});
    }

    pub inline fn configRead(self: PciDevice, comptime size: type, offset: u8) size {
        // ask for access before reading config
        arch.ports.outl(pci_config_address, @bitCast(self.address(offset)));
        switch (size) {
            // read the correct size
            u8 => return arch.ports.inb(pci_config_data),
            u16 => return arch.ports.inw(pci_config_data),
            u32 => return arch.ports.inl(pci_config_data),
            else => @compileError("pci only support reading up to 32 bits"),
        }
    }

    pub fn init(bus: u8, slot: u5, function: u3) PciDevice {
        return PciDevice{ .bus = bus, .slot = slot, .function = function };
    }

    /// The response we get from the base address register. This isn't useful so we want to clean this up and returns a 64
    /// bit address back outside of this package.
    const BarResponse = packed struct(u32) {
        // Whether the address is io mapped or memory mapped
        is_io_mapped: bool,
        address: u31,

        pub const Mem = packed struct(u32) {
            is_io_mapped: bool,
            type: Type,
            prefetchable: bool,
            address: u28,

            pub const Type = enum(u2) {
                Small,
                Reserved,
                Wide
            };
        };

        pub const Io = packed struct(u32) {
            is_io_mapped: bool,
            reserved: u1,
            address: u32,
        };

        pub fn memoryMapped(self: *const BarResponse) Mem {
            return @bitCast(self.*);
        }

        pub fn ioMapped(self: *const BarResponse) Io {
            return @bitCast(self.*);
        }
    };
};

pub const DeviceIterator = struct {
    slot: u8 = 0,
    function: u8 = 0,

    pub fn next(self: *DeviceIterator) ?PciDevice {
        if (self.slot == 32) {
            return null;
        }

        const dev = PciDevice.init(0, @intCast(self.slot), @intCast(self.function));

        if (self.function == 7) {
            self.function = 0;
            self.slot += 1;
        } else {
            self.function += 1;
        }

        if (dev.isEmpty()) {
            return self.next();
        }
        return dev;
    }
};

pub fn iterator() DeviceIterator {
    return .{};
}

pub fn lspci() void {
    var itr = DeviceIterator{};
    while (itr.next()) |dev| {
        dev.format();
    }
}
