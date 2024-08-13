const arch = @import("index.zig");

pub const PS2 = struct {
    data: arch.ports.Port,
    status: arch.ports.Port,
    command: arch.ports.Port,
};

pub fn new(data: u16, status: u16, command: u16) PS2 {
    return PS2{
        .data = arch.ports.new(data),
        .status = arch.ports.new(status),
        .command = arch.ports.new(command),
    };
}