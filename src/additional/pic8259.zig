usingnamespace @import("../common.zig");

const port = structures.port.Portu8;

/// Command sent to begin PIC initialization.
const CMD_INIT: u8 = 0x11;

/// Command sent to acknowledge an interrupt.
const CMD_END_INTERRUPT: u8 = 0x20;

/// The mode in which we want to run our PICs.
const MODE_8086: u8 = 0x01;

const DEFAULT_PRIMARY_MASK: u8 = blk: {
    var temp = PicPrimaryInterruptMask.allMasked();
    temp.chain = false;
    break :blk temp.toU8();
};
const DEFAULT_SECONDARY_MASK: u8 = PicSecondaryInterruptMask.allMasked().toU8();

const PRIMARY_COMMAND_PORT: port = port.init(0x20);
const PRIMARY_DATA_PORT: port = port.init(0x21);
const SECONDARY_COMMAND_PORT: port = port.init(0xA0);
const SECONDARY_DATA_PORT: port = port.init(0xA1);

pub const SimplePic = struct {
    primary_interrupt_offset: u8,
    secondary_interrupt_offset: u8,

    /// Initialize both our PICs.  We initialize them together, at the same
    /// time, because it's traditional to do so, and because I/O operations
    /// might not be instantaneous on older processors.
    ///
    /// NOTE: All interrupts start masked, except the connection from primary to secondary.
    pub fn init(primary_interrupt_offset: u8, secondary_interrupt_offset: u8) SimplePic {
        // We need to add a delay between writes to our PICs, especially on
        // older motherboards.  But we don't necessarily have any kind of
        // timers yet, because most of them require interrupts.  Various
        // older versions of Linux and other PC operating systems have
        // worked around this by writing garbage data to port 0x80, which
        // allegedly takes long enough to make everything work on most
        // hardware.
        const wait_port = port.init(0x80);

        // Tell each PIC that we're going to send it a three-byte
        // initialization sequence on its data port.
        PRIMARY_COMMAND_PORT.write(CMD_INIT);
        wait_port.write(0);
        SECONDARY_COMMAND_PORT.write(CMD_INIT);
        wait_port.write(0);

        // Byte 1: Set up our base offsets.
        PRIMARY_DATA_PORT.write(primary_interrupt_offset);
        wait_port.write(0);
        SECONDARY_DATA_PORT.write(secondary_interrupt_offset);
        wait_port.write(0);

        // Byte 2: Configure chaining between PIC1 and PIC2.
        PRIMARY_DATA_PORT.write(4);
        wait_port.write(0);
        SECONDARY_DATA_PORT.write(2);
        wait_port.write(0);

        // Byte 3: Set our mode.
        PRIMARY_DATA_PORT.write(MODE_8086);
        wait_port.write(0);
        SECONDARY_DATA_PORT.write(MODE_8086);
        wait_port.write(0);

        // Set the default interrupt masks
        PRIMARY_DATA_PORT.write(DEFAULT_PRIMARY_MASK);
        SECONDARY_DATA_PORT.write(DEFAULT_SECONDARY_MASK);

        return .{
            .primary_interrupt_offset = primary_interrupt_offset,
            .secondary_interrupt_offset = secondary_interrupt_offset,
        };
    }

    fn handlesInterrupt(offset: u8, interrupt_id: u8) callconv(.Inline) bool {
        return offset <= interrupt_id and interrupt_id < offset + 8;
    }

    /// Figure out which (if any) PICs in our chain need to know about this interrupt
    pub fn notifyEndOfInterrupt(self: SimplePic, interrupt_id: u8) void {
        if (handlesInterrupt(self.secondary_interrupt_offset, interrupt_id)) {
            SECONDARY_COMMAND_PORT.write(CMD_END_INTERRUPT);
            PRIMARY_COMMAND_PORT.write(CMD_END_INTERRUPT);
        } else if (handlesInterrupt(self.primary_interrupt_offset, interrupt_id)) {
            PRIMARY_COMMAND_PORT.write(CMD_END_INTERRUPT);
        }
    }

    pub fn rawGetPrimaryInterruptMask() callconv(.Inline) PicPrimaryInterruptMask {
        return PicPrimaryInterruptMask.fromU8(PRIMARY_DATA_PORT.read());
    }

    pub fn rawSetPrimaryInterruptMask(mask: PicPrimaryInterruptMask) callconv(.Inline) void {
        PRIMARY_DATA_PORT.write(mask.toU8());
    }

    pub fn rawGetSecondaryInterruptMask() callconv(.Inline) PicSecondaryInterruptMask {
        return PicSecondaryInterruptMask.fromU8(SECONDARY_DATA_PORT.read());
    }

    pub fn rawSetSecondaryInterruptMask(mask: PicSecondaryInterruptMask) callconv(.Inline) void {
        SECONDARY_DATA_PORT.write(mask.toU8());
    }

    pub fn isInterruptMasked(self: SimplePic, interrupt: PicInterrupt) bool {
        return switch (interrupt) {
            // Primary
            .Timer => rawGetPrimaryInterruptMask().timer,
            .Keyboard => rawGetPrimaryInterruptMask().keyboard,
            .Chain => rawGetPrimaryInterruptMask().chain,
            .SerialPort2 => rawGetPrimaryInterruptMask().serial_port_2,
            .SerialPort1 => rawGetPrimaryInterruptMask().serial_port_1,
            .ParallelPort23 => rawGetPrimaryInterruptMask().parallel_port_23,
            .FloppyDisk => rawGetPrimaryInterruptMask().floppy_disk,
            .ParallelPort1 => rawGetPrimaryInterruptMask().parallel_port_1,

            // Secondary
            .RealTimeClock => rawGetSecondaryInterruptMask().real_time_clock,
            .Acpi => rawGetSecondaryInterruptMask().acpi,
            .Available1 => rawGetSecondaryInterruptMask().available_1,
            .Available2 => rawGetSecondaryInterruptMask().available_2,
            .Mouse => rawGetSecondaryInterruptMask().mouse,
            .CoProcessor => rawGetSecondaryInterruptMask().co_processor,
            .PrimaryAta => rawGetSecondaryInterruptMask().primary_ata,
            .SecondaryAta => rawGetSecondaryInterruptMask().secondary_ata,
        };
    }

    fn isPrimaryPic(interrupt: PicInterrupt) callconv(.Inline) bool {
        return switch (interrupt) {
            .Timer, .Keyboard, .Chain, .SerialPort2, .SerialPort1, .ParallelPort23, .FloppyDisk, .ParallelPort1 => true,
            else => false,
        };
    }

    pub fn setInterruptMask(self: SimplePic, interrupt: PicInterrupt, mask: bool) void {
        if (isPrimaryPic(interrupt)) {
            var current_mask = rawGetPrimaryInterruptMask();
            switch (interrupt) {
                .Timer => current_mask.timer = mask,
                .Keyboard => current_mask.keyboard = mask,
                .Chain => current_mask.chain = mask,
                .SerialPort2 => current_mask.serial_port_2 = mask,
                .SerialPort1 => current_mask.serial_port_1 = mask,
                .ParallelPort23 => current_mask.parallel_port_23 = mask,
                .FloppyDisk => current_mask.floppy_disk = mask,
                .ParallelPort1 => current_mask.parallel_port_1 = mask,
                else => unreachable,
            }
            rawSetPrimaryInterruptMask(current_mask);
        } else {
            var current_mask = rawGetSecondaryInterruptMask();
            switch (interrupt) {
                .RealTimeClock => current_mask.real_time_clock = mask,
                .Acpi => current_mask.acpi = mask,
                .Available1 => current_mask.available_1 = mask,
                .Available2 => current_mask.available_2 = mask,
                .Mouse => current_mask.mouse = mask,
                .CoProcessor => current_mask.co_processor = mask,
                .PrimaryAta => current_mask.primary_ata = mask,
                .SecondaryAta => current_mask.secondary_ata = mask,
                else => unreachable,
            }
            rawSetSecondaryInterruptMask(current_mask);
        }
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const PicInterrupt = enum {
    Timer,
    Keyboard,
    Chain,
    SerialPort2,
    SerialPort1,
    ParallelPort23,
    FloppyDisk,
    ParallelPort1,
    RealTimeClock,
    Acpi,
    Available1,
    Available2,
    Mouse,
    CoProcessor,
    PrimaryAta,
    SecondaryAta,
};

pub const PicPrimaryInterruptMask = packed struct {
    timer: bool,
    keyboard: bool,
    chain: bool,
    serial_port_2: bool,
    serial_port_1: bool,
    parallel_port_23: bool,
    floppy_disk: bool,
    parallel_port_1: bool,

    pub fn noneMasked() callconv(.Inline) PicPrimaryInterruptMask {
        return fromU8(0);
    }

    pub fn allMasked() callconv(.Inline) PicPrimaryInterruptMask {
        return fromU8(0b11111111);
    }

    pub fn toU8(value: PicPrimaryInterruptMask) callconv(.Inline) u8 {
        return @bitCast(u8, value);
    }

    pub fn fromU8(value: u8) callconv(.Inline) PicPrimaryInterruptMask {
        return @bitCast(PicPrimaryInterruptMask, value);
    }

    test {
        std.testing.refAllDecls(@This());
        std.testing.expectEqual(@bitSizeOf(u8), @bitSizeOf(PicPrimaryInterruptMask));
        std.testing.expectEqual(@sizeOf(u8), @sizeOf(PicPrimaryInterruptMask));
    }
};

pub const PicSecondaryInterruptMask = packed struct {
    real_time_clock: bool,
    acpi: bool,
    available_1: bool,
    available_2: bool,
    mouse: bool,
    co_processor: bool,
    primary_ata: bool,
    secondary_ata: bool,

    pub fn noneMasked() callconv(.Inline) PicSecondaryInterruptMask {
        return fromU8(0);
    }

    pub fn allMasked() callconv(.Inline) PicSecondaryInterruptMask {
        return fromU8(0b11111111);
    }

    pub fn toU8(value: PicSecondaryInterruptMask) callconv(.Inline) u8 {
        return @bitCast(u8, value);
    }

    pub fn fromU8(value: u8) callconv(.Inline) PicSecondaryInterruptMask {
        return @bitCast(PicSecondaryInterruptMask, value);
    }

    test {
        std.testing.refAllDecls(@This());
        std.testing.expectEqual(@bitSizeOf(u8), @bitSizeOf(PicSecondaryInterruptMask));
        std.testing.expectEqual(@sizeOf(u8), @sizeOf(PicSecondaryInterruptMask));
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
