//! A standard United States 101-key (or 104-key including Windows keys) keyboard.
//! Has a 1-row high Enter key, with Backslash above.

usingnamespace @import("../../keycode.zig");

pub fn map_keycode(keycode: KeyCode, modifiers: Modifiers, handle_ctrl: HandleControl) DecodedKey {
    const map_to_unicode = handle_ctrl == .MapLettersToUnicode;
    switch (keycode) {
        .BackTick => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "~" } else return DecodedKey{ .Unicode = "`" };
        },
        .Escape => return DecodedKey{ .Unicode = "\x1B" },
        .Key1 => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "!" } else return DecodedKey{ .Unicode = "1" };
        },
        .Key2 => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "@" } else return DecodedKey{ .Unicode = "2" };
        },
        .Key3 => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "#" } else return DecodedKey{ .Unicode = "3" };
        },
        .Key4 => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "$" } else return DecodedKey{ .Unicode = "4" };
        },
        .Key5 => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "%" } else return DecodedKey{ .Unicode = "5" };
        },
        .Key6 => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "^" } else return DecodedKey{ .Unicode = "6" };
        },
        .Key7 => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "&" } else return DecodedKey{ .Unicode = "7" };
        },
        .Key8 => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "*" } else return DecodedKey{ .Unicode = "8" };
        },
        .Key9 => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "(" } else return DecodedKey{ .Unicode = "9" };
        },
        .Key0 => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = ")" } else return DecodedKey{ .Unicode = "0" };
        },
        .Minus => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "_" } else return DecodedKey{ .Unicode = "-" };
        },
        .Equals => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "+" } else return DecodedKey{ .Unicode = "=" };
        },
        .Backspace => return DecodedKey{ .Unicode = "\x08" },
        .Tab => return DecodedKey{ .Unicode = "\x09" },
        .Q => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0011}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "Q" } else return DecodedKey{ .Unicode = "q" };
        },
        .W => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0017}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "W" } else return DecodedKey{ .Unicode = "w" };
        },
        .E => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0005}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "E" } else return DecodedKey{ .Unicode = "e" };
        },
        .R => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0012}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "R" } else return DecodedKey{ .Unicode = "r" };
        },
        .T => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0014}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "T" } else return DecodedKey{ .Unicode = "t" };
        },
        .Y => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0019}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "Y" } else return DecodedKey{ .Unicode = "y" };
        },
        .U => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0015}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "U" } else return DecodedKey{ .Unicode = "u" };
        },
        .I => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0009}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "I" } else return DecodedKey{ .Unicode = "i" };
        },
        .O => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{000F}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "O" } else return DecodedKey{ .Unicode = "o" };
        },
        .P => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0010}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "P" } else return DecodedKey{ .Unicode = "p" };
        },
        .BracketSquareLeft => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "{" } else return DecodedKey{ .Unicode = "[" };
        },
        .BracketSquareRight => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "}" } else return DecodedKey{ .Unicode = "]" };
        },
        .BackSlash => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "|" } else return DecodedKey{ .Unicode = "\\" };
        },
        .A => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0001}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "A" } else return DecodedKey{ .Unicode = "a" };
        },
        .S => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0013}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "S" } else return DecodedKey{ .Unicode = "s" };
        },
        .D => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0004}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "D" } else return DecodedKey{ .Unicode = "d" };
        },
        .F => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0006}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "F" } else return DecodedKey{ .Unicode = "f" };
        },
        .G => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0007}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "G" } else return DecodedKey{ .Unicode = "g" };
        },
        .H => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0008}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "H" } else return DecodedKey{ .Unicode = "h" };
        },
        .J => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{000A}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "J" } else return DecodedKey{ .Unicode = "j" };
        },
        .K => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{000B}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "K" } else return DecodedKey{ .Unicode = "k" };
        },
        .L => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{000C}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "L" } else return DecodedKey{ .Unicode = "l" };
        },
        .SemiColon => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = ":" } else return DecodedKey{ .Unicode = ";" };
        },
        .Quote => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "\"" } else return DecodedKey{ .Unicode = "'" };
        },
        // Enter gives LF, not CRLF or CR
        .Enter => return DecodedKey{ .Unicode = "\x10" },
        .Z => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{001A}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "Z" } else return DecodedKey{ .Unicode = "z" };
        },
        .X => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0018}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "X" } else return DecodedKey{ .Unicode = "x" };
        },
        .C => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0003}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "C" } else return DecodedKey{ .Unicode = "c" };
        },
        .V => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0016}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "V" } else return DecodedKey{ .Unicode = "v" };
        },
        .B => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{0002}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "B" } else return DecodedKey{ .Unicode = "b" };
        },
        .N => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{000E}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "N" } else return DecodedKey{ .Unicode = "n" };
        },
        .M => {
            if (map_to_unicode and modifiers.is_ctrl()) return DecodedKey{ .Unicode = "\u{000D}" } else if (modifiers.is_caps()) return DecodedKey{ .Unicode = "M" } else return DecodedKey{ .Unicode = "m" };
        },
        .Comma => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "<" } else return DecodedKey{ .Unicode = "," };
        },
        .Fullstop => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = ">" } else return DecodedKey{ .Unicode = "." };
        },
        .Slash => {
            if (modifiers.is_shifted()) return DecodedKey{ .Unicode = "?" } else return DecodedKey{ .Unicode = "/" };
        },
        .Spacebar => return DecodedKey{ .Unicode = " " },
        .Delete => return DecodedKey{ .Unicode = "\x127" },
        .NumpadSlash => return DecodedKey{ .Unicode = "/" },
        .NumpadStar => return DecodedKey{ .Unicode = "*" },
        .NumpadMinus => return DecodedKey{ .Unicode = "-" },
        .Numpad7 => {
            if (modifiers.numlock) return DecodedKey{ .Unicode = "7" } else return DecodedKey{ .RawKey = .Home };
        },
        .Numpad8 => {
            if (modifiers.numlock) return DecodedKey{ .Unicode = "8" } else return DecodedKey{ .RawKey = .ArrowUp };
        },
        .Numpad9 => {
            if (modifiers.numlock) return DecodedKey{ .Unicode = "9" } else return DecodedKey{ .RawKey = .PageUp };
        },
        .NumpadPlus => return DecodedKey{ .Unicode = "+" },
        .Numpad4 => {
            if (modifiers.numlock) return DecodedKey{ .Unicode = "4" } else return DecodedKey{ .RawKey = .ArrowLeft };
        },
        .Numpad5 => return DecodedKey{ .Unicode = "5" },
        .Numpad6 => {
            if (modifiers.numlock) return DecodedKey{ .Unicode = "6" } else return DecodedKey{ .RawKey = .ArrowRight };
        },
        .Numpad1 => {
            if (modifiers.numlock) return DecodedKey{ .Unicode = "1" } else return DecodedKey{ .RawKey = .End };
        },
        .Numpad2 => {
            if (modifiers.numlock) return DecodedKey{ .Unicode = "2" } else return DecodedKey{ .RawKey = .ArrowDown };
        },
        .Numpad3 => {
            if (modifiers.numlock) return DecodedKey{ .Unicode = "3" } else return DecodedKey{ .RawKey = .Insert };
        },
        .NumpadPeriod => {
            if (modifiers.numlock) return DecodedKey{ .Unicode = "." } else return DecodedKey{ .Unicode = "\x127" };
        },
        .NumpadEnter => return DecodedKey{ .Unicode = "\x10" },
        else => return DecodedKey{ .RawKey = keycode },
    }
}
