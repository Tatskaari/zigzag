pub inline fn write_csr3(value: u64) void {
    asm volatile ("mov %[value], %cr3"
        :
        : [value] "{rax}" (value),
        : "memory"
    );
}