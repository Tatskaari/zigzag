/// The root system descriptor table (rsdt) is a table that contains descriptors for various parts of the system. This
/// is part of the Advanced Configuration and Power Interface (ACPI). This provides, amoungst other things, the
/// Multiple APIC Description Table (MADT) which we need to find out Advanced Programmable Interrupt Controllers (APIC).
///
/// Intel really made this hard for us...
///
/// This package provides functions to search for entries in the RSDT such as the MADT.
const std = @import("std");
const limine = @import("limine");
const kernel = @import("root").kernel;


pub const Error = error{
    HeaderNotFound,
};

const rsdp_desc_sig = [8]u8{ 'R', 'S', 'D', ' ', 'P', 'T', 'R', ' ' };

pub export var rsdp_req: limine.RsdpRequest = .{};

const RSDP = extern struct {
    signature: [8]u8 align(1),
    checksum: u8 align(1),
    oem_id: [6]u8 align(1),
    revision: u8 align(1),
    rsdt: u32 align(1),
};

// System Description Table Header
pub const Header = extern struct {
    signature: [4]u8 align(1),
    length: u32 align(1),
    revision: u8 align(1),
    checksum: u8 align(1),
    oemid: [6]u8 align(1),
    oem_table_id: [8]u8 align(1),
    oem_revision: u32 align(1),
    creator_id: u32 align(1),
    creator_revision: u32 align(1),
};

// Root System Description Table
const RSDT = extern struct {
    header: Header align(1),
    entries: [256]u32 align(1),
};

var rsdp: *RSDP = undefined;
var rsdt : *RSDT = undefined;

pub fn init() void {
    const maybe_rsdp_response = rsdp_req.response;
    if (maybe_rsdp_response == null) {
        @panic("missing limine rsdp response");
    }

    const rsdp_response = maybe_rsdp_response.?;

    // This address is already translated from physical to virtual for us.
    rsdp = @ptrCast(@alignCast(rsdp_response.address));
    if (!std.mem.eql(u8, "RSD PTR ", &rsdp.signature)) {
        @panic("bad rsdp signature");
    }

    // We need to translate this based on the high half direct mapping from limine
    rsdt = @ptrFromInt(kernel.mem.hhdm.virtualFromPhysical(rsdp.rsdt));
    if (!std.mem.eql(u8, "RSDT", &rsdt.header.signature)) {
        @panic("bad RSDT singature");
    }
}

// find_hdr searches for a SDT header in the RSDT
pub fn findHdr(signature: [4]u8) !*Header {
    for(rsdt.entries) |addr| {
        const hdr: *Header = @ptrFromInt(kernel.mem.hhdm.virtualFromPhysical(addr));
        if(std.mem.eql(u8, &hdr.signature, &signature)) {
            return hdr;
        }
    }
    return Error.HeaderNotFound;
}
