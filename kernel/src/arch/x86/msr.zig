
// Write to a Model Specific Register
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

// Read a Model Specific Register
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


