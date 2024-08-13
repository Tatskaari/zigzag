pub inline fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "N{dx}" (port),
    );
}

pub inline fn inw(port: u16) u16 {
    return asm volatile ("inw %[port], %[result]"
        : [result] "={ax}" (-> u16),
        : [port] "N{dx}" (port),
    );
}

pub inline fn inl(port: u16) u32 {
    return asm volatile ("inl %[port], %[result]"
        : [result] "={eax}" (-> u32),
        : [port] "N{dx}" (port),
    );
}

pub inline fn insl(port: u16, addr: anytype, cnt: usize) void {
    asm volatile ("cld; repne; insl;"
        : [addr] "={edi}" (addr),
          [cnt] "={ecx}" (cnt),
        : [port] "{dx}" (port),
          [addr] "0" (addr),
          [cnt] "1" (cnt),
        : "memory", "cc"
    );
}

pub const Port = struct {
    address: u16,

    pub fn write(self: *const Port, comptime Size: type, value: Size) void {
        switch (Size) {
            u8 => outb(self.address, value),
            u16 => outw(self.address, value),
            u32 => outl(self.address, value),
            else => @compileError("ports can only accept u8, u16, or u32"),
        }
    }

    pub fn read(self: *const Port, comptime Size: type) Size {
        switch (Size) {
            u8 => return inb(self.address),
            u16 => return inw(self.address),
            u32 => return inl(self.address),
            else => @compileError("ports can only accept u8, u16, or u32"),
        }
    }
};

pub fn new(address: u16) Port {
    return Port{.address = address};
}

pub inline fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "N{dx}" (port),
    );
}

pub inline fn outw(port: u16, value: u16) void {
    asm volatile ("outw %[value], %[port]"
        :
        : [value] "{ax}" (value),
          [port] "N{dx}" (port),
    );
}

pub inline fn outl(port: u16, value: u32) void {
    asm volatile ("outl %[value], %[port]"
        :
        : [value] "{eax}" (value),
          [port] "N{dx}" (port),
    );
}
