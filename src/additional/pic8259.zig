usingnamespace @import("../common.zig");

const port = structures.port.Portu8;

/// Command sent to begin PIC initialization.
const CMD_INIT: u8 = 0x11;

/// Command sent to acknowledge an interrupt.
const CMD_END_INTERRUPT: u8 = 0x20;

/// The mode in which we want to run our PICs.
const MODE_8086: u8 = 0x01;

const Pic = struct {
    /// The base offset to which our interrupts are mapped.
    offset: u8,
    /// The processor I/O port on which we send commands.
    command: port,
    /// The processor I/O port on which we send and receive data.
    data: port,

    /// Are we in change of handling the specified interrupt?
    /// Each PIC handles 8 interrupts.
    fn handles_interrupt(self: Pic, interrupt_id: u8) bool {
        return self.offset <= interrupt_id and interrupt_id < self.offset + 8;
    }

    /// Notify us that an interrupt has been handled and that we're ready for more.
    fn end_of_interrupt(self: Pic) void {
        self.command.write(CMD_END_INTERRUPT);
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

/// A pair of chained PIC controllers.  This is the standard setup on x86.
pub const ChainedPics = struct {
    pics: [2]Pic,

    /// Create a new interface for the standard PIC1 and PIC2 controllers, specifying the desired interrupt offsets.
    pub fn init(offset1: u8, offset2: u8) ChainedPics {
        return .{
            .pics = [_]Pic{
                .{
                    .offset = offset1,
                    .command = port.init(0x20),
                    .data = port.init(0x21),
                },
                .{
                    .offset = offset2,
                    .command = port.init(0xA0),
                    .data = port.init(0xA1),
                },
            },
        };
    }

    /// Initialize both our PICs.  We initialize them together, at the same
    /// time, because it's traditional to do so, and because I/O operations
    /// might not be instantaneous on older processors.
    pub fn initialise(self: ChainedPics) void {
        // We need to add a delay between writes to our PICs, especially on
        // older motherboards.  But we don't necessarily have any kind of
        // timers yet, because most of them require interrupts.  Various
        // older versions of Linux and other PC operating systems have
        // worked around this by writing garbage data to port 0x80, which
        // allegedly takes long enough to make everything work on most
        // hardware.
        const wait_port = port.init(0x80);

        // Save our original interrupt masks, because I'm too lazy to
        // figure out reasonable values.  We'll restore these when we're
        // done.
        const saved_mask1 = self.pics[0].data.read();
        const saved_mask2 = self.pics[1].data.read();

        // Tell each PIC that we're going to send it a three-byte
        // initialization sequence on its data port.
        self.pics[0].command.write(CMD_INIT);
        wait_port.write(0);
        self.pics[1].command.write(CMD_INIT);
        wait_port.write(0);

        // Byte 1: Set up our base offsets.
        self.pics[0].data.write(self.pics[0].offset);
        wait_port.write(0);
        self.pics[1].data.write(self.pics[1].offset);
        wait_port.write(0);

        // Byte 2: Configure chaining between PIC1 and PIC2.
        self.pics[0].data.write(4);
        wait_port.write(0);
        self.pics[1].data.write(2);
        wait_port.write(0);

        // Byte 3: Set our mode.
        self.pics[0].data.write(MODE_8086);
        wait_port.write(0);
        self.pics[1].data.write(MODE_8086);
        wait_port.write(0);

        // Restore our saved masks.
        self.pics[0].data.write(saved_mask1);
        self.pics[1].data.write(saved_mask2);
    }

    pub const InterruptController = enum {
        Primary,
        Secondary,
    };

    pub fn set_interrupt_mask(self: ChainedPics, controller: InterruptController, interrupt: u3, mask: bool) void {
        switch (controller) {
            .Primary => {
                if (mask) {
                    self.pics[0].data.write(self.pics[0].data.read() | (@as(u8, 1) << interrupt));
                } else {
                    self.pics[0].data.write(self.pics[0].data.read() & ~(@as(u8, 1) << interrupt));
                }
            },
            .Secondary => {
                if (mask) {
                    self.pics[1].data.write(self.pics[1].data.read() | @as(u8, 1) << interrupt);
                } else {
                    self.pics[1].data.write(self.pics[1].data.read() & ~(@as(u8, 1) << interrupt));
                }
            },
        }
    }

    /// Do we handle this interrupt?
    pub fn handles_interrupt(self: ChainedPics, interrupt_id: u8) bool {
        return self.pics[0].handles_interrupt(interrupt_id) or self.pics[1].handles_interrupt(interrupt_id);
    }

    /// Figure out which (if any) PICs in our chain need to know about this
    /// interrupt.  This is tricky, because all interrupts from `pics[1]`
    /// get chained through `pics[0]`.
    pub fn notify_end_of_interrupt(self: ChainedPics, interrupt_id: u8) void {
        if (self.pics[1].handles_interrupt(interrupt_id)) {
            self.pics[1].end_of_interrupt();
        } else if (self.pics[0].handles_interrupt(interrupt_id)) {
            self.pics[0].end_of_interrupt();
        }
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "" {
    std.testing.refAllDecls(@This());
}
