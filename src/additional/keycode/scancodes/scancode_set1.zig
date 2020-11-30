/// Contains the implementation of Scancode Set 1.
/// See the OS dev wiki: https://wiki.osdev.org/PS/2_Keyboard#Scan_Code_Set_1
const std = @import("std");
usingnamespace @import("../../keycode.zig");

pub const EXTENDED_KEY_CODE: u8 = 0xE0;
pub const KEY_RELEASE_CODE: u8 = 0xF0;

/// Implements state logic for scancode set 1
///
/// Start:
/// E0 => Extended
/// >= 0x80 => Key Up
/// <= 0x7F => Key Down
///
/// Extended:
/// >= 0x80 => Extended Key Up
/// <= 0x7F => Extended Key Down
pub fn advance_state(state: *DecodeState, code: u8) KeyboardError!?KeyEvent {
    switch (state.*) {
        .Start => {
            if (code == EXTENDED_KEY_CODE) state.* = .Extended else if (code >= 0x80 and code <= 0xFF) return KeyEvent{ .code = try map_scancode(code - 0x80), .state = .Up } else return KeyEvent{ .code = try map_scancode(code), .state = .Down };
        },
        .Extended => {
            state.* = .Start;
            switch (code) {
                0x80...0xFF => return KeyEvent{ .code = try map_extended_scancode(code - 0x80), .state = .Up },
                else => return KeyEvent{ .code = try map_extended_scancode(code), .state = .Down },
            }
        },
        else => unreachable,
    }
    return null;
}

/// Implements the single byte codes for Set 1.
fn map_scancode(code: u8) KeyboardError!KeyCode {
    return switch (code) {
        0x01 => .Escape,
        0x02 => .Key1,
        0x03 => .Key2,
        0x04 => .Key3,
        0x05 => .Key4,
        0x06 => .Key5,
        0x07 => .Key6,
        0x08 => .Key7,
        0x09 => .Key8,
        0x0A => .Key9,
        0x0B => .Key0,
        0x0C => .Minus,
        0x0D => .Equals,
        0x0E => .Backspace,
        0x0F => .Tab,
        0x10 => .Q,
        0x11 => .W,
        0x12 => .E,
        0x13 => .R,
        0x14 => .T,
        0x15 => .Y,
        0x16 => .U,
        0x17 => .I,
        0x18 => .O,
        0x19 => .P,
        0x1A => .BracketSquareLeft,
        0x1B => .BracketSquareRight,
        0x1C => .Enter,
        0x1D => .ControlLeft,
        0x1E => .A,
        0x1F => .S,
        0x20 => .D,
        0x21 => .F,
        0x22 => .G,
        0x23 => .H,
        0x24 => .J,
        0x25 => .K,
        0x26 => .L,
        0x27 => .SemiColon,
        0x28 => .Quote,
        0x29 => .BackTick,
        0x2A => .ShiftLeft,
        0x2B => .BackSlash,
        0x2C => .Z,
        0x2D => .X,
        0x2E => .C,
        0x2F => .V,
        0x30 => .B,
        0x31 => .N,
        0x32 => .M,
        0x33 => .Comma,
        0x34 => .Fullstop,
        0x35 => .Slash,
        0x36 => .ShiftRight,
        0x37 => .NumpadStar,
        0x38 => .AltLeft,
        0x39 => .Spacebar,
        0x3A => .CapsLock,
        0x3B => .F1,
        0x3C => .F2,
        0x3D => .F3,
        0x3E => .F4,
        0x3F => .F5,
        0x40 => .F6,
        0x41 => .F7,
        0x42 => .F8,
        0x43 => .F9,
        0x44 => .F10,
        0x45 => .NumpadLock,
        0x46 => .ScrollLock,
        0x47 => .Numpad7,
        0x48 => .Numpad8,
        0x49 => .Numpad9,
        0x4A => .NumpadMinus,
        0x4B => .Numpad4,
        0x4C => .Numpad5,
        0x4D => .Numpad6,
        0x4E => .NumpadPlus,
        0x4F => .Numpad1,
        0x50 => .Numpad2,
        0x51 => .Numpad3,
        0x52 => .Numpad0,
        0x53 => .NumpadPeriod,
        //0x54
        //0x55
        //0x56
        0x57 => .F11,
        0x58 => .F12,
        0x81...0xD8 => map_scancode(code - 0x80),
        else => KeyboardError.UnknownKeyCode,
    };
}

/// Implements the extended byte codes for set 1 (prefixed with E0)
fn map_extended_scancode(code: u8) KeyboardError!KeyCode {
    return switch (code) {
        0x10 => .PrevTrack,
        0x19 => .NextTrack,
        0x1C => .NumpadEnter,
        0x1D => .ControlRight,
        0x20 => .Mute,
        0x21 => .Calculator,
        0x22 => .Play,
        0x24 => .Stop,
        0x2E => .VolumeDown,
        0x30 => .VolumeUp,
        0x32 => .WWWHome,
        0x35 => .NumpadSlash,
        0x38 => .AltRight,
        0x47 => .Home,
        0x48 => .ArrowUp,
        0x49 => .PageUp,
        0x4B => .ArrowLeft,
        0x4D => .ArrowRight,
        0x4F => .End,
        0x50 => .ArrowDown,
        0x51 => .PageDown,
        0x52 => .Insert,
        0x53 => .Delete,
        0x90...0xED => map_extended_scancode(code - 0x80),
        else => KeyboardError.UnknownKeyCode,
    };
}
