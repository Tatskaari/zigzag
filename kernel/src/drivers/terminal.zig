const std = @import("std");
const limine = @import("limine");
const kernel = @import("kernel");

const vga = @import("vga.zig");

pub export var framebuffer_request: limine.FramebufferRequest = .{};

pub const Terminal = struct {
    vga: vga.VGA = vga.VGA{ .fb = undefined },
    col: u32 = 0,
    line: u32 = 0,
    width: u32,
    height: u32,
    fg: u32 = @intFromEnum(vga.Gravbox.FG),
    bg: u32 = @intFromEnum(vga.Gravbox.BG),

    history: [][]u8,

    pub const Writer = std.io.Writer(
        *Terminal,
        error{},
        writeAll,
    );

    pub fn writer(self: *Terminal) Writer {
        return .{ .context = self };
    }

    pub fn init(self: *Terminal, alloc: std.mem.Allocator, fb: *limine.Framebuffer, max_history: usize) void {
        self.vga.fb = fb;
        self.vga.clear(self.bg);
        self.width = @intCast(@divFloor(fb.width, vga.font.glyph_width));
        self.height = @intCast(@divFloor(fb.height, vga.font.glyph_height));

        self.history = alloc.alloc([]u8, max_history) catch @panic("oom creating terminal");

        // Zero these out incase the memory has some nonsense in it
        for (0..self.history.len) |i| {
            self.history[i] = alloc.alloc(u8, self.width) catch @panic("oom creating terminal");
            for (0..self.history[i].len) |j| {
                self.history[i][j] = 0;
            }
        }
    }

    pub fn set_char(self: *Terminal, col: u32, row: u32, char: u8) void {
        const x = col;
        const y = @mod(row, self.history.len);
        self.history[y][x] = char;
        self.draw_char(col, row);
    }

    pub fn get_char(self: *Terminal, col: usize, row: usize) u8 {
        const x = col;
        const y = @mod(row, self.history.len);
        return self.history[y][x];
    }

    // Convert a line in terminal history to a line in screen space
    pub fn term_to_screen(self: *Terminal, line: usize) usize {
        if (self.line < self.height) {
            return line;
        }

        return self.height - (self.line - line) - 1;
    }

    pub fn draw_char(self: *Terminal, col: u32, line: u32) void {
        const char = self.get_char(col, line);
        const row = self.term_to_screen(line);
        if (char == 0) {
            self.vga.drawCharAt(col, row, ' ', self.fg, self.bg);
        } else {
            self.vga.drawCharAt(col, row, char, self.fg, self.bg);
        }
    }

    // TODO is this really a concept in the driver? We probably need to expose a few primitives here that can be
    //  implemented by the TTY service
    pub fn draw_cursor(self: *Terminal) void {
        const row = self.term_to_screen(self.line);
        self.vga.drawCharAt(self.col, row, '_', self.fg, self.bg);
    }

    pub fn redraw(self: *Terminal) void {
        for (0..self.height) |y| {
            if(y > self.line) {
                break;
            }
            for (0..self.width) |x| {
                self.draw_char(@intCast(x), @intCast(self.line - y));
            }
        }
    }

    fn new_line(self: *Terminal) void {
        self.line = self.line + 1;
        self.col = 0;
        self.redraw();

        const mod_line = @mod(self.line+1, self.history.len);
        for (0..self.width) |j| {
            self.history[mod_line][j] = 0;
        }
    }

    pub fn write(self: *Terminal, c: u8) void {
        if (c == '\n') {
            self.new_line();
            self.draw_cursor();
            return;
        }
        if (c == '\r') {
            return;
        }

        self.set_char(self.col, self.line, c);
        self.col = self.col + 1;
        if (self.col >= self.width) {
            self.new_line();
        }
        self.draw_cursor();
    }

    pub fn writeAll(self: *Terminal, bytes: []const u8) error{}!usize {
        for (bytes) |c| {
            self.write(c);
        }
        return bytes.len;
    }

    pub fn clear(self: *Terminal) void {
        for(0..self.history.len) |i| {
            for(0..self.width) |j| {
                self.history[i][j] = 0;
            }
        }
        self.redraw();
        self.line = 0;
        self.col = 0;
        self.draw_cursor();
    }
};

pub var tty = Terminal{
    .vga = undefined,
    .width = undefined,
    .height = undefined,
    .history = undefined,
};

pub fn init(alloc: std.mem.Allocator) void {
    if (framebuffer_request.response) |framebuffer_response| {
        if (framebuffer_response.framebuffer_count < 1) {
            @panic("failed to init terminal: no frame buffer found");
        }
        vga.font.init();
        tty.init(alloc, framebuffer_response.framebuffers()[0], 100);
    }
}

pub fn print(comptime format: []const u8, args: anytype) void {
    const w = tty.writer();
    std.fmt.format(w, format, args) catch unreachable;
}
