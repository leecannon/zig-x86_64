const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

/// Obtains the bit at the index `bit`; note that index 0 is the least significant bit, while
/// index `length() - 1` is the most significant bit.
///
/// ```zig
/// const a: u8 = 0b00000010;
///
/// testing.expect(!get_bit(a, 0));
/// testing.expect(get_bit(a, 1));
/// ```
///
/// ## Panics
///
/// This method will panic if the bit index is out of bounds of the bit field.
pub inline fn get_bit(target: anytype, comptime bit: comptime_int) bool {
    const target_type = @TypeOf(target);
    comptime {
        if (@typeInfo(target_type) != .Int and @typeInfo(target_type) != .ComptimeInt) @compileError("not an integer");
        if (bit >= @bitSizeOf(target_type)) @compileError("bit index is out of bounds of the bit field");
    }
    return target & (@as(target_type, 1) << bit) != 0;
}

/// Obtains the range of bits starting at `start_bit` of length `length`; note that index 0 is the least significant
/// bit, while index `length() - 1` is the most significant bit.
///
/// ```zig
/// const a: u8 = 0b01101100;
/// const b = get_bits(a, 2, 4);
/// testing.expectEqual(@as(u8,0b00001011), b);
/// ```
///
/// ## Panics
///
/// This method will panic if the start or end indexes of the range are out of bounds of the
/// bit array, or if the range can't be contained by the bit field T.
pub fn get_bits(target: anytype, comptime start_bit: comptime_int, comptime length: comptime_int) @TypeOf(target) {
    const target_type = @TypeOf(target);

    comptime {
        if (@typeInfo(target_type) != .Int and @typeInfo(target_type) != .ComptimeInt) @compileError("not an integer");
        if (length <= 0) @compileError("length must be greater than zero");
        if (start_bit >= @bitSizeOf(target_type)) @compileError("start_bit index is out of bounds of the bit field");
        if (start_bit + length > @bitSizeOf(target_type)) @compileError("start_bit plus length is out of bounds of the bit field");
    }

    // shift away high bits
    const bits = target << (@bitSizeOf(target_type) - (start_bit + length)) >> (@bitSizeOf(target_type) - (start_bit + length));

    // shift away low bits
    return bits >> start_bit;
}

/// Sets the bit at the index `bit` to the value `value` (where true means a value of '1' and
/// false means a value of '0'); note that index 0 is the least significant bit, while index
/// `length() - 1` is the most significant bit.
///
/// ```zig
/// var val: u8 = 0b00000000;
/// testing.expect(!get_bit(val, 0));
/// set_bit( &val, 0, true);
/// testing.expect(get_bit(val, 0));
/// ```
///
/// ## Panics
///
/// This method will panic if the bit index is out of the bounds of the bit field.
pub inline fn set_bit(target: anytype, comptime bit: comptime_int, value: bool) void {
    const ptr_type_info: std.builtin.TypeInfo = @typeInfo(@TypeOf(target));
    comptime {
        if (ptr_type_info != .Pointer) @compileError("not a pointer");
    }

    const target_type = ptr_type_info.Pointer.child;

    comptime {
        if (@typeInfo(target_type) != .Int and @typeInfo(target_type) != .ComptimeInt) @compileError("not an integer");
        if (bit >= @bitSizeOf(target_type)) @compileError("bit index is out of bounds of the bit field");
    }

    if (value) {
        target.* |= @as(target_type, 1) << bit;
    } else {
        target.* &= ~(@as(target_type, 1) << bit);
    }
}

/// Sets the range of bits starting at `start_bit` of length `length`; to be
/// specific, if the range is N bits long, the N lower bits of `value` will be used; if any of
/// the other bits in `value` are set to 1, this function will panic.
///
/// ```zig
/// var val: u8 = 0b10000000;
/// set_bits(&val, 2, 4, 0b00001101);
/// testing.expectEqual(@as(u8, 0b10110100), val);
/// ```
///
/// ## Panics
///
/// This method will panic if the range is out of bounds of the bit array,
/// if the range can't be contained by the bit field T, or if there are `1`s
/// not in the lower N bits of `value`.
pub fn set_bits(target: anytype, comptime start_bit: comptime_int, comptime length: comptime_int, value: anytype) void {
    const ptr_type_info: std.builtin.TypeInfo = @typeInfo(@TypeOf(target));
    comptime {
        if (ptr_type_info != .Pointer) @compileError("not a pointer");
    }

    const target_type = ptr_type_info.Pointer.child;

    comptime {
        if (@typeInfo(target_type) != .Int and @typeInfo(target_type) != .ComptimeInt) @compileError("not an integer");
        if (length <= 0) @compileError("length must be greater than zero");
        if (start_bit >= @bitSizeOf(target_type)) @compileError("start_bit index is out of bounds of the bit field");
        if (start_bit + length > @bitSizeOf(target_type)) @compileError("start_bit plus length is out of bounds of the bit field");
    }

    if (get_bits(@as(target_type, value), 0, length) != value) {
        @panic("value exceeds bit range");
    }

    const end = start_bit + length;

    const bitmask: target_type = ~(~@as(target_type, 0) << (@bitSizeOf(target_type) - end) >> (@bitSizeOf(target_type) - end) >> start_bit << start_bit);

    target.* = (target.* & bitmask) | (value << start_bit);
}

test "get_bit" {
    const a: u8 = 0b00000000;
    testing.expect(!get_bit(a, 0));
    testing.expect(!get_bit(a, 1));

    const b: u8 = 0b11111111;
    testing.expect(get_bit(b, 0));
    testing.expect(get_bit(b, 1));

    const c: u8 = 0b00000010;
    testing.expect(!get_bit(c, 0));
    testing.expect(get_bit(c, 1));
}

test "get_bits" {
    const a: u8 = 0b01101100;
    const b = get_bits(a, 2, 4);
    testing.expectEqual(@as(u8, 0b00001011), b);
}

test "set_bit" {
    var val: u8 = 0b00000000;
    testing.expect(!get_bit(val, 0));
    set_bit(&val, 0, true);
    testing.expect(get_bit(val, 0));
    set_bit(&val, 0, false);
    testing.expect(!get_bit(val, 0));
}

test "set_bits" {
    var val: u8 = 0b10000000;
    set_bits(&val, 2, 4, 0b00001101);
    testing.expectEqual(@as(u8, 0b10110100), val);
}

test "" {
    std.meta.refAllDecls(@This());
}
