const limine = @import("limine");

pub const WHITE: u32 = 0xFFFFFFFF;
pub const BLACK: u32 = 0x00000000;

pub const Font = struct {
    data: []const u8,
    glyph_width: usize,
    glyph_height: usize,

    pub fn getByte(self: *Font, c: u8, i: usize) u8 {
        return self.data[@as(usize, c) * 16 + i];
    }
};

pub const font: Font = .{
    .data = @import("assets").vga_font,
    .glyph_width = 8,
    .glyph_height = 16,
};

pub const VGA = struct {
    fb: *limine.Framebuffer,

    pub fn putPixel(self: *VGA, x: usize, y: usize, colour: u32) void {
        const pixelPos = y * self.fb.pitch + x * (self.fb.bpp / 8);
        @as(*u32, @ptrCast(@alignCast(self.fb.address + pixelPos))).* = colour;
    }

    pub fn drawCharAt(self: *VGA, col: usize, row: usize, char: u8, fg: u32, bg: u32) void {
        const x = col * font.glyph_width;
        const y = row * font.glyph_height;

        for (0..16) |i| {
            self.drawByteAt(x, y+i, font.data[@as(usize, char)*font.glyph_height + i], fg, bg);
        }
    }

    fn drawBitAt(self: *VGA, x: usize, y: usize, bit: bool, fg: u32, bg: u32) void {
        if (bit) {
            self.putPixel(x, y, fg);
        } else {
            self.putPixel(x, y, bg);
        }
    }

    fn drawByteAt(self: *VGA, x: usize, y: usize, byte: u8, fg: u32, bg: u32) void {
        self.drawBitAt(x + 0, y, byte & 0b10000000 != 0, fg, bg);
        self.drawBitAt(x + 1, y, byte & 0b01000000 != 0, fg, bg);
        self.drawBitAt(x + 2, y, byte & 0b00100000 != 0, fg, bg);
        self.drawBitAt(x + 3, y, byte & 0b00010000 != 0, fg, bg);
        self.drawBitAt(x + 4, y, byte & 0b00001000 != 0, fg, bg);
        self.drawBitAt(x + 5, y, byte & 0b00000100 != 0, fg, bg);
        self.drawBitAt(x + 6, y, byte & 0b00000010 != 0, fg, bg);
        self.drawBitAt(x + 6, y, byte & 0b00000001 != 0, fg, bg);
    }
};
