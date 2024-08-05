const std = @import("std");
const limine = @import("limine");

const vga = @import("vga.zig");

pub export var framebuffer_request: limine.FramebufferRequest = .{};

const InitError = error {
    NoFrameBuffers,
};

pub const Terminal = struct {
    vga: vga.VGA = vga.VGA{.fb = undefined},
    col: usize = 0,
    row: usize = 0,
    width: usize,
    height: usize,
    fg: u32 = vga.WHITE,
    bg: u32 = vga.BLACK,

    pub const Writer = std.io.Writer(
        *Terminal,
        error{},
        writeAll,
    );

    pub fn writer(self: *Terminal) Writer {
        return .{ .context = self };
    }

    pub fn init(self: *Terminal, fb: *limine.Framebuffer) void {
        self.vga.fb = fb;
        tty.width = @divFloor(fb.width, vga.font.glyph_width);
        tty.height = @divFloor(fb.width, vga.font.glyph_height);
    }

    pub fn write(self: *Terminal, c: u8) void {
        if(c == '\n') {
            self.row = self.row + 1;
            self.col = 0;
            return;
        }
        if(c == '\r') {
            return;
        }
        self.vga.drawCharAt(self.col, self.row, c, self.fg, self.bg);

        self.col = self.col + 1;
        if (self.col > self.width) {
            self.col = 0;
            self.row = self.row + 1;
        }

        // Just loop back round to the top
        if(self.row > self.height) {
            self.row = 0;
        }
    }

    pub fn writeAll(self: *Terminal, bytes: []const u8) error{}!usize {
        for(bytes) |c| {
            self.write(c);
        }
        return bytes.len;
    }
};

pub var tty = Terminal{
    .vga = undefined,
    .width = undefined,
    .height = undefined,
};


pub fn init() InitError!void {
    if (framebuffer_request.response) |framebuffer_response| {
        if (framebuffer_response.framebuffer_count < 1) {
            return InitError.NoFrameBuffers;
        }

        tty.init(framebuffer_response.framebuffers()[0]);
    }
}

pub fn print(comptime format: []const u8, args: anytype) void {
    const w = tty.writer();
    std.fmt.format(w, format, args) catch unreachable;
}