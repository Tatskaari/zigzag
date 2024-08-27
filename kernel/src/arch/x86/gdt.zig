/// gdt implements the global descriptor table

const kernel = @import("kernel");
const cpu = @import("cpu.zig");

/// SegmentDescriptor represents an entry in the GDT. Most of these fields are not relevant for long mode as we use
/// paging instead, however we need to have a code and data segment to set the ring code is executing at.
const SegmentDescriptor = packed struct(u64) {
    limit_lo: u16 = 0,
    base_address_lo: u16 = 0,
    base_address_hi: u8 = 0,
    access: Access,
    limit_hi: u4 = 0,
    reserved_1: u1 = 0,
    long_mode: bool = true,
    reserved_2: u1 = 0,
    use_chunks: bool = false, // Whether the limit represents 0x1000 chunks or just bytes
    base_address_ext: u8 = 0,

    const Access = packed struct(u8) {
        accessed: bool = true,
        read_write: bool = true, // If set, code segments are readable, data segments are writable
        grow_down_or_conforming: bool = false, // If set, the segment grows down for data, or for code, sets if it's conforming
        is_code: bool,
        not_system: bool = true,
        ring: u2,
        present: bool = true,
    };
};

const null_segment = SegmentDescriptor{
    .access = .{
        .read_write = false,
        .is_code = false,
        .grow_down_or_conforming = false,
        .ring = 0,
    },
};

const kernel_code = SegmentDescriptor{
    .access = .{
        .is_code = true,
        .ring = 0,
    },
};

const kernel_data = SegmentDescriptor{
    .access = .{
        .is_code = false,
        .ring = 0,
    },
};

const user_code = SegmentDescriptor{
    .access = .{
        .is_code = true,
        .ring = 0,
    },
};

const user_data = SegmentDescriptor{
    .access = .{
        .is_code = false,
        .ring = 0,
    },
};

const GDT = [5]SegmentDescriptor{
    null_segment, // null selector
    kernel_code,
    kernel_data,
    user_code,
    user_data,
};

pub const kernel_cs = 1 * @sizeOf(SegmentDescriptor);
pub const kernel_ds = 2 * @sizeOf(SegmentDescriptor);
pub const user_cs = 3 * @sizeOf(SegmentDescriptor);
pub const user_ds = 4 * @sizeOf(SegmentDescriptor);

const Gdtr = packed struct(u80) {
    limit: u16,
    base: u64,
};

pub noinline fn flushGdt() void {
    // Loads the data selectors, then does a dummy far return to the next instruction, setting the code selector
    asm volatile (
        \\ mov $0x10, %ax
        \\ mov %ax, %ds
        \\ mov %ax, %es
        \\ mov %ax, %fs
        \\ mov %ax, %fs
        \\ mov %ax, %ss
        \\ pushq $0x08
        \\ pushq $dummy
        \\ lretq
        \\
        \\ dummy:
    );
}

pub fn init() void {
    const gdtr = Gdtr{
        .base = @intFromPtr(&GDT[0]),
        .limit = @sizeOf(@TypeOf(GDT)) - 1,
    };
    cpu.lgdt(@bitCast(gdtr));
    flushGdt();
}
