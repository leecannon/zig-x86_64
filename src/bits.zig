const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

/// Obtains the bit at the index `bit`; note that index 0 is the least significant bit, while
/// index `length() - 1` is the most significant bit.
///
/// ```zig
/// const a: u8 = 0b00000010;
///
/// testing.expect(!getBit(a, 0));
/// testing.expect(getBit(a, 1));
/// ```
pub fn getBit(target: anytype, comptime bit: comptime_int) bool {
    const target_type = @TypeOf(target);
    comptime {
        if (@typeInfo(target_type) != .Int and @typeInfo(target_type) != .ComptimeInt) @compileError("not an integer");
        if (bit >= @bitSizeOf(target_type)) @compileError("bit index is out of bounds of the bit field");
    }
    return target & (@as(target_type, 1) << bit) != 0;
}

/// Obtains the range of bits starting at `start_bit` upto and excluding `end_bit`
/// Where `start_bit` is of a lower significant bit than `end_bit`
///
/// ```zig
/// const a: u8 = 0b01101100;
/// const b = getBits(a, 2, 6);
/// testing.expectEqual(@as(u8,0b00001011), b);
/// ```
pub fn getBits(target: anytype, comptime start_bit: comptime_int, comptime end_bit: comptime_int) @TypeOf(target) {
    const target_type = @TypeOf(target);

    comptime {
        if (@typeInfo(target_type) != .Int and @typeInfo(target_type) != .ComptimeInt) @compileError("not an integer");
        if (end_bit <= start_bit) @compileError("length must be greater than zero");
        if (start_bit >= @bitSizeOf(target_type)) @compileError("start_bit index is out of bounds of the bit field");
        if (end_bit > @bitSizeOf(target_type)) @compileError("end_bit is out of bounds of the bit field");
    }

    // shift away high bits
    const bits = target << (@bitSizeOf(target_type) - end_bit) >> (@bitSizeOf(target_type) - end_bit);

    // shift away low bits
    return bits >> start_bit;
}

/// Sets the bit at the index `bit` to the value `value` (where true means a value of '1' and
/// false means a value of '0'); note that index 0 is the least significant bit, while index
/// `length() - 1` is the most significant bit.
///
/// ```zig
/// var val: u8 = 0b00000000;
/// testing.expect(!getBit(val, 0));
/// setBit( &val, 0, true);
/// testing.expect(getBit(val, 0));
/// ```
pub fn setBit(target: anytype, comptime bit: comptime_int, value: bool) void {
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

/// Sets the range of bits starting at `start_bit` upto and excluding `end_bit`; to be
/// specific, if the range is N bits long, the N lower bits of `value` will be used; if any of
/// the other bits in `value` are set to 1, this function will panic.
///
/// ```zig
/// var val: u8 = 0b10000000;
/// setBits(&val, 2, 6, 0b00001101);
/// testing.expectEqual(@as(u8, 0b10110100), val);
/// ```
///
/// ## Panics
/// This method will panic if the `value` exceeds the bit range of the type of `target`
pub fn setBits(target: anytype, comptime start_bit: comptime_int, comptime end_bit: comptime_int, value: anytype) void {
    const ptr_type_info: std.builtin.TypeInfo = @typeInfo(@TypeOf(target));
    comptime {
        if (ptr_type_info != .Pointer) @compileError("not a pointer");
    }

    const targetType = ptr_type_info.Pointer.child;

    comptime {
        if (@typeInfo(targetType) != .Int and @typeInfo(targetType) != .ComptimeInt) @compileError("not an integer");
        if (end_bit <= start_bit) @compileError("length must be greater than zero");
        if (start_bit >= @bitSizeOf(targetType)) @compileError("start_bit index is out of bounds of the bit field");
        if (end_bit > @bitSizeOf(targetType)) @compileError("start_bit plus length is out of bounds of the bit field");
    }

    const peer_value = @as(targetType, value);

    if (getBits(peer_value, 0, (end_bit - start_bit)) != peer_value) {
        @panic("value exceeds bit range");
    }

    const bitmask: targetType = comptime ~(~@as(targetType, 0) << (@bitSizeOf(targetType) - end_bit) >> (@bitSizeOf(targetType) - end_bit) >> start_bit << start_bit);

    target.* = (target.* & bitmask) | (peer_value << start_bit);
}

test "getBit" {
    const a: u8 = 0b00000000;
    testing.expect(!getBit(a, 0));
    testing.expect(!getBit(a, 1));

    const b: u8 = 0b11111111;
    testing.expect(getBit(b, 0));
    testing.expect(getBit(b, 1));

    const c: u8 = 0b00000010;
    testing.expect(!getBit(c, 0));
    testing.expect(getBit(c, 1));
}

test "getBits" {
    const a: u8 = 0b01101100;
    const b = getBits(a, 2, 6);
    testing.expectEqual(@as(u8, 0b00001011), b);
}

test "setBit" {
    var val: u8 = 0b00000000;
    testing.expect(!getBit(val, 0));
    setBit(&val, 0, true);
    testing.expect(getBit(val, 0));
    setBit(&val, 0, false);
    testing.expect(!getBit(val, 0));
}

test "setBits" {
    var val: u8 = 0b10000000;
    setBits(&val, 2, 6, 0b00001101);
    testing.expectEqual(@as(u8, 0b10110100), val);
}

comptime {
    std.testing.refAllDecls(@This());
}
