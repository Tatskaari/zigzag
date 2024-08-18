/// Model specific register
pub const msr = struct {
    pub inline fn write(register: usize, value: usize) void {
        const lo: u32 = @truncate(value);
        const hi: u32 = @truncate(value >> 32);

        asm volatile ("wrmsr"
            :
            : [register] "{ecx}" (register),
              [value_low] "{eax}" (lo),
              [value_high] "{edx}" (hi),
        );
    }

    pub inline fn read(register: usize) u64 {
        var lo: u32 = undefined;
        var hi: u32 = undefined;

        asm volatile ("rdmsr"
            : [value_low] "={eax}" (lo),
              [value_high] "={edx}" (hi),
            : [register] "{ecx}" (register),
        );

        return (@as(usize, hi) << 32) | lo;
    }
};

/// Control register (points to the page L4 page table directory)
pub const cr3 = struct {
    pub inline fn write(value: u64) void {
        asm volatile ("mov %[value], %cr3"
            :
            : [value] "{rax}" (value),
            : "memory"
        );
    }

    pub inline fn read() u64 {
        return asm volatile ("mov %cr3, %[result]"
            : [result] "={rax}" (-> u64),
        );
    }
};