const limine = @import("limine");
const std = @import("std");
const drivers = @import("drivers");

// Set the base revision to 2, this is recommended as this is the latest
// base revision described by the Limine boot protocol specification.
// See specification for further info.
pub export var base_revision: limine.BaseRevision = .{ .revision = 2 };

inline fn done() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

const Font = struct {
    data: []const u8,
    glyph_width: usize,
    glyph_height: usize,

    fn fontBytes(self: *const Font, idx: usize) []const u8 {
        const start = self.fontWidth() * idx;
        return self.data[start..(start + self.fontWidth())];
    }
};

const font: Font = .{
    .data = @embedFile("assets/fonts/vga8x16.bin"),
    .glyph_width = 8,
    .glyph_height = 16,
};

fn putPixel(fb: *const limine.Framebuffer, x: usize, y: usize, colour: u32) void {
    const pixelPost = y * fb.pitch + x * (fb.bpp/8);
    @as(*u32, @ptrCast(@alignCast(fb.address + pixelPost))).* = colour;
}

fn drawBitAt(fb: *const limine.Framebuffer, x: usize, y: usize, bit: bool, fg: u32, bg: u32) void {
    if(bit) {
        putPixel(fb, x, y, fg);
    } else {
        putPixel(fb, x, y, bg);
    }
}

fn drawByteAt(fb: *const limine.Framebuffer, x: usize, y: usize, byte: u8, fg: u32, bg: u32) void {
    drawBitAt(fb, x+0, y, byte & 0b10000000 != 0, fg, bg);
    drawBitAt(fb, x+1, y, byte & 0b01000000 != 0, fg, bg);
    drawBitAt(fb, x+2, y, byte & 0b00100000 != 0, fg, bg);
    drawBitAt(fb, x+3, y, byte & 0b00010000 != 0, fg, bg);
    drawBitAt(fb, x+4, y, byte & 0b00001000 != 0, fg, bg);
    drawBitAt(fb, x+5, y, byte & 0b00000100 != 0, fg, bg);
    drawBitAt(fb, x+6, y, byte & 0b00000010 != 0, fg, bg);
    drawBitAt(fb, x+6, y, byte & 0b00000001 != 0, fg, bg);
}

fn putc(fb: *const limine.Framebuffer, col: usize, row: usize, char: u8) void {
    const x = col * font.glyph_width;
    const y = row * font.glyph_height;

    for(0..16) |i| {
        drawByteAt(fb, x, y+i, font.data[@as(usize, char)*16 + i], 0xFFFFFFFF, 0x0);
    }
}

fn print(fb: *const limine.Framebuffer, str: []const u8) void {
    for(0..str.len)|x| {
        putc(fb, x, 0, str[x]);
    }
}

// The following will be our kernel's entry point.
export fn _start() callconv(.C) noreturn {
    // Ensure the bootloader actually understands our base revision (see spec).
    if (!base_revision.is_supported()) {
        done();
    }

    drivers.terminal.init() catch {
        done();
    };

    drivers.terminal.print("hello world {}\n", .{10});
    drivers.terminal.print("hello world {}\n", .{10});

    // We're done, just hang...
    done();
}
