//! Contains the implementation of Scancode Set 2.
//! See the OS dev wiki: https://wiki.osdev.org/PS/2_Keyboard#Scan_Code_Set_2

const std = @import("std");
usingnamespace @import("../../keycode.zig");

pub const EXTENDED_KEY_CODE: u8 = 0xE0;
pub const KEY_RELEASE_CODE: u8 = 0xF0;

/// Implements state logic for scancode set 2
///
/// Start:
/// F0 => Release
/// E0 => Extended
/// xx => Key Down
///
/// Release:
/// xxx => Key Up
///
/// Extended:
/// F0 => Release Extended
/// xx => Extended Key Down
///
/// Release Extended:
/// xxx => Extended Key Up
pub fn advance_state(state: *DecodeState, code: u8) KeyboardError!?KeyEvent {
    switch (state.*) {
        .Start => switch (code) {
            EXTENDED_KEY_CODE => state.* = .Extended,
            KEY_RELEASE_CODE => state.* = .Release,
            else => return KeyEvent{ .code = try map_scancode(code), .state = .Down },
        },
        .Extended => switch (code) {
            KEY_RELEASE_CODE => state.* = .ExtendedRelease,
            else => {
                state.* = .Start;
                return KeyEvent{ .code = try map_extended_scancode(code), .state = .Down };
            },
        },
        .Release => {
            state.* = .Start;
            return KeyEvent{ .code = try map_scancode(code), .state = .Up };
        },
        .ExtendedRelease => {
            state.* = .Start;
            return KeyEvent{ .code = try map_extended_scancode(code), .state = .Up };
        },
    }

    return null;
}

/// Implements the single byte codes for Set 2.
fn map_scancode(code: u8) KeyboardError!KeyCode {
    return switch (code) {
        0x01 => .F9,
        0x03 => .F5,
        0x04 => .F3,
        0x05 => .F1,
        0x06 => .F2,
        0x07 => .F12,
        0x09 => .F10,
        0x0A => .F8,
        0x0B => .F6,
        0x0C => .F4,
        0x0D => .Tab,
        0x0E => .BackTick,
        0x11 => .AltLeft,
        0x12 => .ShiftLeft,
        0x14 => .ControlLeft,
        0x15 => .Q,
        0x16 => .Key1,
        0x1A => .Z,
        0x1B => .S,
        0x1C => .A,
        0x1D => .W,
        0x1e => .Key2,
        0x21 => .C,
        0x22 => .X,
        0x23 => .D,
        0x24 => .E,
        0x25 => .Key4,
        0x26 => .Key3,
        0x29 => .Spacebar,
        0x2A => .V,
        0x2B => .F,
        0x2C => .T,
        0x2D => .R,
        0x2E => .Key5,
        0x31 => .N,
        0x32 => .B,
        0x33 => .H,
        0x34 => .G,
        0x35 => .Y,
        0x36 => .Key6,
        0x3A => .M,
        0x3B => .J,
        0x3C => .U,
        0x3D => .Key7,
        0x3E => .Key8,
        0x41 => .Comma,
        0x42 => .K,
        0x43 => .I,
        0x44 => .O,
        0x45 => .Key0,
        0x46 => .Key9,
        0x49 => .Fullstop,
        0x4A => .Slash,
        0x4B => .L,
        0x4C => .SemiColon,
        0x4D => .P,
        0x4E => .Minus,
        0x52 => .Quote,
        0x54 => .BracketSquareLeft,
        0x55 => .Equals,
        0x58 => .CapsLock,
        0x59 => .ShiftRight,
        0x5A => .Enter,
        0x5B => .BracketSquareRight,
        0x5D => .HashTilde,
        0x61 => .BackSlash,
        0x66 => .Backspace,
        0x69 => .Numpad1,
        0x6B => .Numpad4,
        0x6C => .Numpad7,
        0x70 => .Numpad0,
        0x71 => .NumpadPeriod,
        0x72 => .Numpad2,
        0x73 => .Numpad5,
        0x74 => .Numpad6,
        0x75 => .Numpad8,
        0x76 => .Escape,
        0x77 => .NumpadLock,
        0x78 => .F11,
        0x79 => .NumpadPlus,
        0x7A => .Numpad3,
        0x7B => .NumpadMinus,
        0x7C => .NumpadStar,
        0x7D => .Numpad9,
        0x7E => .ScrollLock,
        0x83 => .F7,
        0xAA => .PowerOnTestOk,
        else => KeyboardError.UnknownKeyCode,
    };
}

/// Implements the extended byte codes for set 1 (prefixed with E0)
fn map_extended_scancode(code: u8) KeyboardError!KeyCode {
    return switch (code) {
        0x11 => .AltRight,
        0x14 => .ControlRight,
        0x1F => .WindowsLeft,
        0x27 => .WindowsRight,
        0x2F => .Menus,
        0x4A => .NumpadSlash,
        0x5A => .NumpadEnter,
        0x69 => .End,
        0x6B => .ArrowLeft,
        0x6C => .Home,
        0x70 => .Insert,
        0x71 => .Delete,
        0x72 => .ArrowDown,
        0x74 => .ArrowRight,
        0x75 => .ArrowUp,
        0x7A => .PageDown,
        0x7D => .PageUp,
        else => KeyboardError.UnknownKeyCode,
    };
}
