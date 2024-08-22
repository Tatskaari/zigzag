/// This file is the entrypoint for @import("kernel") and provides a convinient way to access all our components

/// Contains kernel services such as memory (and soon to be other things like scheduling, filesystems, and the tty)
/// This is where we implement our syscall ABI
pub const services = @import("services/index.zig");

/// Provides drivers for hardware
pub const drivers = @import("drivers/index.zig");

/// Provides an API into the architecture. This is very x86 sepcific but should ideally be a common interface
pub const arch = @import("arch/index.zig");

/// Just some assets that are embedded in the binary (just the terminal font for now)
pub const assets = @import("assets/assets.zig");