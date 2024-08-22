const std = @import("std");
const ports = @import("kernel").arch.ports;

const SerialError = error{
    LoopbackTestFailed,
};

pub const PortAddresses = struct {
    pub const COM1: u16 = 0x3F8;
};

pub const COM1 = SerialPort{
    .port = PortAddresses.COM1,
};

pub const SerialPort = struct {
    port: u16,

    pub const Writer = std.io.Writer(
        *const SerialPort,
        error{},
        writeAll,
    );

    pub fn writer(self: *const SerialPort) Writer {
        return .{ .context = self };
    }

    pub fn init(self: *const SerialPort) !void {
        ports.outb(self.port + 1, 0x00); // Disable all interrupts
        ports.outb(self.port + 3, 0x80); // Enable DLAB (set baud rate divisor)
        ports.outb(self.port + 0, 0x03); // Set divisor to 3 (lo byte) 38400 baud
        ports.outb(self.port + 1, 0x00); //                  (hi byte)
        ports.outb(self.port + 3, 0x03); // 8 bits, no parity, one stop bit
        ports.outb(self.port + 2, 0xC7); // Enable FIFO, clear them, with 14-byte threshold
        ports.outb(self.port + 4, 0x0B); // IRQs enabled, RTS/DSR set

        ports.outb(self.port + 4, 0x1E); // Set in loopback mode, test the serial chip
        ports.outb(self.port + 0, 0xAE); // Test serial chip (send byte 0xAE and check if serial returns same byte)

        // Check if serial is faulty (i.e: not same byte as sent)
        if (ports.inb(self.port + 0) != 0xAE) {
            return SerialError.LoopbackTestFailed;
        }

        // If serial is not faulty set it in normal operation mode
        // (not-loopback with IRQs enabled and OUT#1 and OUT#2 bits enabled)
        ports.outb(self.port + 4, 0x0F);
    }

    pub fn writec(self: *const SerialPort, c: u8) void {
        while (self.is_transmit_empty()) {}
        ports.outb(self.port, c);
    }

    pub fn writeAll(self: *const SerialPort, bytes: []const u8) error{}!usize {
        for (bytes) |c| {
            self.writec(c);
        }
        return bytes.len;
    }

    fn received(self: *const SerialPort) u8 {
        return ports.inb(self.port + 5) & 1;
    }

    pub fn sgetc(self: *const SerialPort) u8 {
        // Hang until we get a byte
        while (self.received() == 0) {}
        return ports.inb(self.port);
    }

    pub fn read(self:*const SerialPort, dest: [*]u8, count: usize) void {
        for (0..count) |i| {
            dest[i] = self.sgetc();
        }
    }

    fn is_transmit_empty(self: *const SerialPort) bool {
        return ports.inb(self.port + 5) & 0x20 == 0;
    }
};

pub fn init() void {
    COM1.init() catch unreachable;
}
