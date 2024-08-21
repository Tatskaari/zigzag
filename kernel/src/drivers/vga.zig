const limine = @import("limine");

/// Some nice colours I found online
pub const GravboxColourScheme = enum(u32) {
    BG = 0x282828,
    FG = 0xebdbb2,
};

pub const Font = struct {
    data: []const u8,
    glyph_width: usize = 0,
    glyph_height: usize = 0,
    hdr_size: usize = 0,

    pub fn init(self: *Font) void {
        if (self.data[0] == 0x36 and self.data[1] == 0x4) {
            self.glyph_height = self.data[3];
            self.glyph_width = @divExact(self.glyph_height, 2);
            self.hdr_size = 4;
        } else {
            @panic("Unsuported font format");
        }
    }

    pub fn getByte(self: *Font, c: u8, i: usize) u8 {
        return self.data[@as(usize, c) * self.glyph_height + i + self.hdr_size];
    }
};

pub var font: Font = .{
    .data = @import("root").assets.vga_font,
};

pub const VGA = struct {
    fb: *limine.Framebuffer,

    pub fn clear(self: *VGA, colour: u32) void {
        for(0..self.fb.width) |x| {
            for(0..self.fb.height) |y| {
                self.putPixel(x, y, colour);
            }
        }
    }

    pub fn putPixel(self: *VGA, x: usize, y: usize, colour: u32) void {
        const pixelPos = y * self.fb.pitch + x * (self.fb.bpp / 8);
        @as(*u32, @ptrCast(@alignCast(self.fb.address + pixelPos))).* = colour;
    }

    pub fn drawCharAt(self: *VGA, col: usize, row: usize, char: u8, fg: u32, bg: u32) void {
        const x = col * font.glyph_width;
        const y = row * font.glyph_height;

        for (0..16) |i| {
            self.drawByteAt(x, y+i, font.getByte(char, i), fg, bg);
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
        for(0..8) |bit| {
            self.drawBitAt(x + bit, y, byte & (@as(u8, 0b10000000) >> @truncate(bit)) != 0, fg, bg);
        }
    }
};
