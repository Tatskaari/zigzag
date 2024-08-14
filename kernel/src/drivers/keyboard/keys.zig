// TODO arrow keys
pub const Key = enum(u8) {
    Esc,
    One,
    Two,
    Three,
    Four,
    Five,
    Six,
    Seven,
    Eight,
    Nine,
    Zero,
    Minus,
    Equals,
    Backspace,
    Tab,
    Q,
    W,
    E,
    R,
    T,
    Y,
    U,
    I,
    O,
    P,
    SquareLeft,
    SquareRight,
    Enter,
    LeftCtl,
    A,
    S,
    D,
    F,
    G,
    H,
    J,
    K,
    L,
    SemiColon,
    SingleQuote,
    BackTick,
    LeftShift,
    Backslash,
    Z,
    X,
    C,
    V,
    B,
    N,
    M,
    Comma,
    Period,
    ForwardSlash,
    RightShift,
    LeftAlt,
    Space,
    CapsLock,
    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,
    Hash,
    Unknown,
};

// KeyChars maps the value of a key to a character
const KeyChars = [_]u8{
    0, // Esc
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '0',
    '-',
    '=',
    0, // Backspace
    '\t',
    'q',
    'w',
    'e',
    'r',
    't',
    'y',
    'u',
    'i',
    'o',
    'p',
    '[',
    ']',
    '\n',
    0, // LeftCtl
    'a',
    's',
    'd',
    'f',
    'g',
    'h',
    'j',
    'k',
    'l',
    ';',
    '\'',
    '`',
    0, // LeftShift
    '\\',
    'z',
    'x',
    'c',
    'v',
    'b',
    'n',
    'm',
    ',',
    '.',
    '/',
    0, // RightShift
    0, // LeftAlt
    ' ',
    0, // F1 - F12
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    '#',
    0, // Unknown
};

// KeyChars maps the value of a key to a character
const KeyShiftChars = [_]u8{
    0, // Esc
    '!',
    '"',
    '£',
    '$',
    '%',
    '^',
    '&',
    '*',
    '(',
    ')',
    '_',
    '+',
    0, // Backspace
    0, // Tab
    'Q',
    'W',
    'E',
    'R',
    'T',
    'Y',
    'U',
    'I',
    'O',
    'P',
    '{',
    '}',
    0,
    0, // LeftCtl
    'A',
    'S',
    'D',
    'F',
    'G',
    'H',
    'J',
    'K',
    'L',
    ':',
    '@',
    '¬',
    0, // LeftShift
    '|',
    'Z',
    'X',
    'C',
    'V',
    'B',
    'N',
    'M',
    '<',
    '>',
    '?',
    0, // RightShift
    0, // LeftAlt
    0,
    0, // F1 - F12
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    '~',
    0, // Unknown
};

const scancode_set_1 = [_]Key{
    Key.Unknown, // This is the zero value and isn't in the scancodes
    Key.Esc,
    Key.One,
    Key.Two,
    Key.Three,
    Key.Four,
    Key.Five,
    Key.Six,
    Key.Seven,
    Key.Eight,
    Key.Nine,
    Key.Zero,
    Key.Minus,
    Key.Equals,
    Key.Backspace,
    Key.Tab,
    Key.Q,
    Key.W,
    Key.E,
    Key.R,
    Key.T,
    Key.Y,
    Key.U,
    Key.I,
    Key.O,
    Key.P,
    Key.SquareLeft,
    Key.SquareRight,
    Key.Enter,
    Key.LeftCtl,
    Key.A,
    Key.S,
    Key.D,
    Key.F,
    Key.G,
    Key.H,
    Key.J,
    Key.K,
    Key.L,
    Key.SemiColon,
    Key.SingleQuote,
    Key.BackTick,
    Key.LeftShift,
    Key.Hash,
    Key.Z,
    Key.X,
    Key.C,
    Key.V,
    Key.B,
    Key.N,
    Key.M,
    Key.Comma,
    Key.Period,
    Key.ForwardSlash,
    Key.RightShift,
    Key.Unknown, // * on the keypad
    Key.LeftAlt,
    Key.Space,
    Key.CapsLock,
    Key.F1,
    Key.F2,
    Key.F3,
    Key.F4,
    Key.F5,
    Key.F6,
    Key.F7,
    Key.F8,
    Key.F9,
    Key.F10,
    Key.Unknown, // Various numpad and other keys we don't support yet
    Key.Unknown,
    Key.Unknown,
    Key.Unknown,
    Key.Unknown,
    Key.Unknown,
    Key.Unknown,
    Key.Unknown,
    Key.Unknown,
    Key.Unknown,
    Key.Unknown,
    Key.Unknown,
    Key.Unknown,
    Key.Unknown,
    Key.Unknown,
    Key.Unknown,
    Key.Unknown,
    Key.Backslash,
    Key.F11,
    Key.F12,
    Key.Unknown, // More numpad stuff
    Key.Unknown,
    Key.Unknown,
    Key.Unknown,
    Key.Unknown,
};

var extended_mode = false;
const ext_code = 0xE0;

// The keys repeat after 0x80 but represent release events
pub const key_count = 0x80;
const released_offset = key_count;

pub const KeyEvent = struct {
    key: Key,
    // Whether this event is a press or release event
    pressed: bool,
};

pub fn translate(scan_code: u8) ?KeyEvent {
    if (scan_code == ext_code) {
        extended_mode = true;
        return null;
    }

    var sc = scan_code;
    const released = scan_code > 0x80;
    if (scan_code > released_offset) {
        sc = scan_code - released_offset;
    }


    // TODO the other scancode translations
    const key = if(sc < scancode_set_1.len) scancode_set_1[sc] else Key.Unknown;
    extended_mode = false;
    return KeyEvent{
        .key = key,
        .pressed = !released,
    };
}

pub fn keyToASCII(shift_held: bool, key: Key) u8 {
    const idx = @intFromEnum(key);
    if(shift_held) {
        return KeyShiftChars[idx];
    }
    return KeyChars[idx];
}
