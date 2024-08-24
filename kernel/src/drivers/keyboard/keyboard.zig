const arch = @import("kernel").arch;
const std = @import("std");
const keys = @import("keys.zig");

// TODO pass in event listeners to on key press
const terminal = @import("../terminal.zig");

const data_port = 0x60;
const status_port = 0x64;
const command_port = status_port;

const disable_port_1 : u8 = 0xAD;
const enable_port_1 = disable_port_1 + 0x01;
const disable_port_2 : u8 = 0xA7;
const enable_port_2 = disable_port_2 + 0x01;

// The ps/2 keyboard is connected to port 1 of the IO apic
const io_apic_entry_num = 1;

const set_scan_code_cmd = 0xF0;

const scan_code_1 = 0x43;
const scan_code_2 = 0x41;
const scan_code_3 = 0x3f;

const Listener = struct {
    ptr: *anyopaque,
    onEventFn: *const fn (ptr: *anyopaque, event: keys.KeyEvent) void,

    fn onKeyEvent(self: *const Listener, event: keys.KeyEvent) void {
        self.onEventFn(self.ptr, event);
    }

    fn init(ptr: anytype) Listener {
        const T = @TypeOf(ptr);
        const ptr_info = @typeInfo(T);

        const gen = struct {
            pub fn onKeyEvent(pointer: *anyopaque, event: keys.KeyEvent) void {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.Pointer.child.onKeyEvent(self, event);
            }
        };

        return .{
            .ptr = ptr,
            .onEventFn = gen.onKeyEvent,
        };
    }
};

// TODO this should be more like an event stream rather than doing everything in the interupt handler
const Ps2Keyboard = struct {
    ps2: arch.ps2.PS2,
    // TODO we should probably make this an ArrayList once we have an allocator to have multiple listeners
    key_event_listeners: [10]Listener = undefined,
    key_event_listenr_count: usize = 0,

    pub fn read(self: *const Ps2Keyboard) u8 {
        return self.ps2.data.read(u8);
    }

    pub fn enable(self: *const Ps2Keyboard) void {
        self.ps2.command.write(enable_port_1);
        self.ps2.command.write(enable_port_2);
    }

    pub fn disable(self: *const Ps2Keyboard) void {
        self.ps2.command.write(disable_port_1);
        self.ps2.command.write(disable_port_2);
    }

    pub fn keyPressed(self: *const Ps2Keyboard) void {
        const scancode = self.read();
        if (keys.translate(scancode)) |event| {
            for (0..self.key_event_listenr_count) |i| {
                const l = self.key_event_listeners[i];
                l.onKeyEvent(event);
            }
        }
    }

    pub fn addListener(self: *Ps2Keyboard, l: Listener) void {
        self.key_event_listeners[self.key_event_listenr_count] = l;
        self.key_event_listenr_count = self.key_event_listenr_count + 1;
    }
};

// TODO this probably belongs somewhere else e.g. the terminal package
const TerminalKeyboard = struct {
    caps_lock: bool = false,
    key_state: [keys.key_count]bool = std.mem.zeroes([keys.key_count]bool),

    pub fn listener(self: *TerminalKeyboard) Listener {
        return Listener.init(self);
    }

    pub fn isPressed(self: *TerminalKeyboard, key: keys.Key) bool {
        return self.key_state[@intFromEnum(key)];
    }

    pub fn isCaps(self: *TerminalKeyboard) bool {
        return self.caps_lock or self.isShiftPressed();
    }

    pub fn isCtrPressed(self: *TerminalKeyboard) bool {
        return self.isPressed(keys.Key.LeftCtl);
    }

    pub fn isShiftPressed(self: *TerminalKeyboard) bool {
        return self.isPressed(keys.Key.LeftShift) or self.isPressed(keys.Key.RightShift);
    }

    pub fn onKeyEvent(self: *TerminalKeyboard, event: keys.KeyEvent) void {
        self.key_state[@intFromEnum(event.key)] = event.pressed;
        if (event.key == keys.Key.CapsLock and event.pressed) {
            // TODO I think this should actually come from the keyboard
            self.caps_lock = !self.caps_lock;
        }

        if (event.pressed) {
            self.onPress(event);
        }
    }

    fn onPress(self: *TerminalKeyboard, event: keys.KeyEvent) void {
        if (self.handleShortcut(event)) {
            return;
        }

        if (event.key == keys.Key.Backspace and terminal.tty.col > 0) {
            terminal.tty.setChar(terminal.tty.col, terminal.tty.line, 0); // For the cursor
            terminal.tty.col = terminal.tty.col - 1;
            terminal.tty.setChar(terminal.tty.col, terminal.tty.line, 0);
            terminal.tty.drawCursor();
            return;
        }

        const char = keys.keyToASCII(self.isCaps(), event.key);
        if (char != 0) {
            terminal.tty.write(char);
            return;
        }
    }

    fn handleShortcut(self: *TerminalKeyboard, event: keys.KeyEvent) bool {
        if (!self.isCtrPressed()) {
            return false;
        }
        if (event.key == keys.Key.L) {
            terminal.tty.clear();
        }
        return true;
    }
};

var isr1_keyboard = TerminalKeyboard{};

var isr1_ps2_keyboard = Ps2Keyboard{
    .ps2 = arch.ps2.new(data_port, status_port, command_port),
};

// The keyboard is connected to pin 1 on the io apic i.e. isr1
export fn isr1(_: *arch.cpu.Context) callconv(.C) void {
    isr1_ps2_keyboard.keyPressed();
    arch.lapic.get_lapic().end();
}

fn initRedirectTables(ioapic: *const arch.ioapic.APIC, vec: u8) void {
    var entry = ioapic.readRedirectEntry(io_apic_entry_num);
    entry.mask = false;
    entry.vector = vec;
    entry.destination_mode = arch.ioapic.DestinationMode.physical;
    entry.destination = @truncate(arch.lapic.get_lapic().getId());
    ioapic.writeRedirectEntry(io_apic_entry_num, entry);
}

pub fn init(ioapic: *const arch.ioapic.APIC) void {
    const vec = arch.idt.registerInterrupt(&isr1, 0);
    initRedirectTables(ioapic, vec);
    isr1_ps2_keyboard.enable();
    isr1_ps2_keyboard.addListener(isr1_keyboard.listener());
}
