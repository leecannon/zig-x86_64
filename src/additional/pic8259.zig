usingnamespace @import("../common.zig");

const port = structures.port.Portu8;

/// Command sent to begin PIC initialization.
const CMD_INIT: u8 = 0x11;

/// Command sent to acknowledge an interrupt.
const CMD_END_INTERRUPT: u8 = 0x20;

/// The mode in which we want to run our PICs.
const MODE_8086: u8 = 0x01;

const defaultPrimaryMask: u8 = blk: {
    var temp = PicPrimaryInterruptMask.all_masked();
    temp.CHAIN = false;
    break :blk temp.to_u8();
};
const defaultSecondaryMask: u8 = PicSecondaryInterruptMask.all_masked().to_u8();

const primaryCommand: port = port.init(0x20);
const primaryData: port = port.init(0x21);
const secondaryCommand: port = port.init(0xA0);
const secondaryData: port = port.init(0xA1);

pub const SimplePic = struct {
    primaryInterruptOffset: u8,
    secondaryInterruptOffset: u8,

    /// Initialize both our PICs.  We initialize them together, at the same
    /// time, because it's traditional to do so, and because I/O operations
    /// might not be instantaneous on older processors.
    ///
    /// NOTE: All interrupts start masked, except the connection from primary to secondary.
    pub fn init(primaryInterruptOffset: u8, secondaryInterruptOffset: u8) SimplePic {
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
        primaryCommand.write(CMD_INIT);
        wait_port.write(0);
        secondaryCommand.write(CMD_INIT);
        wait_port.write(0);

        // Byte 1: Set up our base offsets.
        primaryData.write(primaryInterruptOffset);
        wait_port.write(0);
        secondaryData.write(secondaryInterruptOffset);
        wait_port.write(0);

        // Byte 2: Configure chaining between PIC1 and PIC2.
        primaryData.write(4);
        wait_port.write(0);
        secondaryData.write(2);
        wait_port.write(0);

        // Byte 3: Set our mode.
        primaryData.write(MODE_8086);
        wait_port.write(0);
        secondaryData.write(MODE_8086);
        wait_port.write(0);

        // Set the default interrupt masks
        primaryData.write(defaultPrimaryMask);
        secondaryData.write(defaultSecondaryMask);

        return .{
            .primaryInterruptOffset = primaryInterruptOffset,
            .secondaryInterruptOffset = secondaryInterruptOffset,
        };
    }

    inline fn handlesInterrupt(offset: u8, interrupt_id: u8) bool {
        return offset <= interrupt_id and interrupt_id < offset + 8;
    }

    /// Figure out which (if any) PICs in our chain need to know about this interrupt
    pub fn notify_end_of_interrupt(self: SimplePic, interrupt_id: u8) void {
        if (handlesInterrupt(self.secondaryInterruptOffset, interrupt_id)) {
            secondaryCommand.write(CMD_END_INTERRUPT);
            primaryCommand.write(CMD_END_INTERRUPT);
        } else if (handlesInterrupt(self.primaryInterruptOffset, interrupt_id)) {
            primaryCommand.write(CMD_END_INTERRUPT);
        }
    }

    pub fn raw_getPrimaryInterruptMask() PicPrimaryInterruptMask {
        return PicPrimaryInterruptMask.from_u8(primaryData.read());
    }

    pub fn raw_setPrimaryInterruptMask(mask: PicPrimaryInterruptMask) void {
        primaryData.write(mask.to_u8());
    }

    pub fn raw_getSecondaryInterruptMask() PicSecondaryInterruptMask {
        return PicSecondaryInterruptMask.from_u8(secondaryData.read());
    }

    pub fn raw_setSecondaryInterruptMask(mask: PicSecondaryInterruptMask) void {
        secondaryData.write(mask.to_u8());
    }

    pub fn isInterruptMasked(self: SimplePic, interrupt: PicInterrupt) bool {
        return switch (interrupt) {
            // Primary
            .Timer => raw_getPrimaryInterruptMask().TIMER,
            .Keyboard => raw_getPrimaryInterruptMask().KEYBOARD,
            .Chain => raw_getPrimaryInterruptMask().CHAIN,
            .SerialPort2 => raw_getPrimaryInterruptMask().SERIAL_PORT_2,
            .SerialPort1 => raw_getPrimaryInterruptMask().SERIAL_PORT_1,
            .ParallelPort23 => raw_getPrimaryInterruptMask().PARALLEL_PORT_23,
            .FloppyDisk => raw_getPrimaryInterruptMask().FLOPPY_DISK,
            .ParallelPort1 => raw_getPrimaryInterruptMask().PARALLEL_PORT_1,

            // Secondary
            .RealTimeClock => raw_getSecondaryInterruptMask().REAL_TIME_CLOCK,
            .Acpi => raw_getSecondaryInterruptMask().ACPI,
            .Available1 => raw_getSecondaryInterruptMask().AVAILABLE_1,
            .Available2 => raw_getSecondaryInterruptMask().AVAILABLE_2,
            .Mouse => raw_getSecondaryInterruptMask().MOUSE,
            .CoProcessor => raw_getSecondaryInterruptMask().CO_PROCESSOR,
            .PrimaryAta => raw_getSecondaryInterruptMask().PRIMARY_ATA,
            .SecondaryAta => raw_getSecondaryInterruptMask().SECONDARY_ATA,
        };
    }

    inline fn isPrimaryPic(interrupt: PicInterrupt) bool {
        return switch (interrupt) {
            .Timer, .Keyboard, .Chain, .SerialPort2, .SerialPort1, .ParallelPort23, .FloppyDisk, .ParallelPort1 => true,
            else => false,
        };
    }

    pub fn setInterruptMask(self: SimplePic, interrupt: PicInterrupt, mask: bool) void {
        if (isPrimaryPic(interrupt)) {
            var current_mask = raw_getPrimaryInterruptMask();
            switch (interrupt) {
                .Timer => current_mask.TIMER = mask,
                .Keyboard => current_mask.KEYBOARD = mask,
                .Chain => current_mask.CHAIN = mask,
                .SerialPort2 => current_mask.SERIAL_PORT_2 = mask,
                .SerialPort1 => current_mask.SERIAL_PORT_1 = mask,
                .ParallelPort23 => current_mask.PARALLEL_PORT_23 = mask,
                .FloppyDisk => current_mask.FLOPPY_DISK = mask,
                .ParallelPort1 => current_mask.PARALLEL_PORT_1 = mask,
                else => unreachable,
            }
            raw_setPrimaryInterruptMask(current_mask);
        } else {
            var current_mask = raw_getSecondaryInterruptMask();
            switch (interrupt) {
                .RealTimeClock => current_mask.REAL_TIME_CLOCK = mask,
                .Acpi => current_mask.ACPI = mask,
                .Available1 => current_mask.AVAILABLE_1 = mask,
                .Available2 => current_mask.AVAILABLE_2 = mask,
                .Mouse => current_mask.MOUSE = mask,
                .CoProcessor => current_mask.CO_PROCESSOR = mask,
                .PrimaryAta => current_mask.PRIMARY_ATA = mask,
                .SecondaryAta => current_mask.SECONDARY_ATA = mask,
                else => unreachable,
            }
            raw_setSecondaryInterruptMask(current_mask);
        }
    }

    test "" {
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
    TIMER: bool,
    KEYBOARD: bool,
    CHAIN: bool,
    SERIAL_PORT_2: bool,
    SERIAL_PORT_1: bool,
    PARALLEL_PORT_23: bool,
    FLOPPY_DISK: bool,
    PARALLEL_PORT_1: bool,

    pub inline fn none_masked() PicPrimaryInterruptMask {
        return from_u8(0);
    }

    pub inline fn all_masked() PicPrimaryInterruptMask {
        return from_u8(0b11111111);
    }

    pub inline fn to_u8(value: PicPrimaryInterruptMask) u8 {
        return @bitCast(u8, value);
    }

    pub inline fn from_u8(value: u8) PicPrimaryInterruptMask {
        return @bitCast(PicPrimaryInterruptMask, value);
    }

    test "" {
        std.testing.expectEqual(@bitSizeOf(u8), @bitSizeOf(PicPrimaryInterruptMask));
        std.testing.expectEqual(@sizeOf(u8), @sizeOf(PicPrimaryInterruptMask));
    }
};

pub const PicSecondaryInterruptMask = packed struct {
    REAL_TIME_CLOCK: bool,
    ACPI: bool,
    AVAILABLE_1: bool,
    AVAILABLE_2: bool,
    MOUSE: bool,
    CO_PROCESSOR: bool,
    PRIMARY_ATA: bool,
    SECONDARY_ATA: bool,

    pub inline fn none_masked() PicSecondaryInterruptMask {
        return from_u8(0);
    }

    pub inline fn all_masked() PicSecondaryInterruptMask {
        return from_u8(0b11111111);
    }

    pub inline fn to_u8(value: PicSecondaryInterruptMask) u8 {
        return @bitCast(u8, value);
    }

    pub inline fn from_u8(value: u8) PicSecondaryInterruptMask {
        return @bitCast(PicSecondaryInterruptMask, value);
    }

    test "" {
        std.testing.expectEqual(@bitSizeOf(u8), @bitSizeOf(PicSecondaryInterruptMask));
        std.testing.expectEqual(@sizeOf(u8), @sizeOf(PicSecondaryInterruptMask));
    }
};

test "" {
    std.testing.refAllDecls(@This());
}
