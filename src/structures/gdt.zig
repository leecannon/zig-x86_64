usingnamespace @import("../common.zig");

/// Specifies which element to load into a segment from
/// descriptor tables (i.e., is a index to LDT or GDT table
/// with some additional flags).
///
/// See Intel 3a, Section 3.4.2 "Segment Selectors"
pub const SegmentSelector = packed struct {
    selector: u16,

    /// Creates a new SegmentSelector
    ///
    /// # Arguments
    ///  * `index`: index in GDT or LDT array (not the offset)
    ///  * `rpl`: the requested privilege level
    pub inline fn new(index: u16, rpl: PrivilegeLevel) SegmentSelector {
        return SegmentSelector{ .selector = index << 3 | @as(u16, @enumToInt(rpl)) };
    }

    /// Returns the GDT index.
    pub inline fn gdt_index(self: SegmentSelector) u16 {
        return self.selector >> 3;
    }

    /// Returns the requested privilege level.
    pub inline fn get_rpl(self: SegmentSelector) PrivilegeLevel {
        return PrivilegeLevel.from_u16(get_bits(self.selector, 0, 2));
    }

    /// Set the privilege level for this Segment selector.
    pub inline fn set_rpl(self: *SegmentSelector, rpl: PrivilegeLevel) void {
        set_bits(&self.selector, 0, 2, @as(u16, @enumToInt(rpl)));
    }

    pub fn format(value: SegmentSelector, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        const SegmentSelectorFormat = struct {
            index: u16,
            rpl: PrivilegeLevel,
        };
        try std.fmt.formatType(SegmentSelectorFormat{ .index = value.gdt_index(), .rpl = value.get_rpl() }, fmt, options, writer, 1);
    }
};

test "SegmentSelector" {
    var a = SegmentSelector.new(1, .Ring0);
    testing.expectEqual(@as(u16, 1), a.gdt_index());
    testing.expectEqual(PrivilegeLevel.Ring0, a.get_rpl());
    a.set_rpl(.Ring3);
    testing.expectEqual(@as(u16, 1), a.gdt_index());
    testing.expectEqual(PrivilegeLevel.Ring3, a.get_rpl());
}

/// A 64-bit mode global descriptor table (GDT).
///
/// In 64-bit mode, segmentation is not supported. The GDT is used nonetheless, for example for
/// switching between user and kernel mode or for loading a TSS.
///
/// The GDT has a fixed size of 8 entries, trying to add more entries will panic.
///
/// You do **not** need to add a null segment descriptor yourself - this is already done
/// internally.
///
/// Data segment registers in ring 0 can be loaded with the null segment selector. When running in
/// ring 3, the `ss` register must point to a valid data segment which can be obtained through the
/// `user_data_segment()` function. Code segments must be valid and non-null at all times and can be obtained through
/// the `kernel_code_segment()` and `user_code_segment()` in rings 0 and 3 respectively.
///
/// For more info, see:
/// [x86 Instruction Reference for `mov`](https://www.felixcloutier.com/x86/mov#64-bit-mode-exceptions),
/// [Intel Manual](https://software.intel.com/sites/default/files/managed/39/c5/325462-sdm-vol-1-2abcd-3abcd.pdf),
/// [AMD Manual](https://www.amd.com/system/files/TechDocs/24593.pdf)
///
/// # Example
/// ```zig
///
/// var gdt = GlobalDescriptorTable.new();
/// gdt.add_entry(kernel_code_segment());
/// gdt.add_entry(user_code_segment());
/// gdt.add_entry(user_data_segment());
///
/// // Add entry for TSS, call gdt.load() then update segment registers
/// ```
pub const GlobalDescriptorTable = struct {
    table: [8]u64,
    next_free: u16,

    /// Creates an empty GDT.
    pub inline fn new() GlobalDescriptorTable {
        return GlobalDescriptorTable{
            .table = [_]u64{0} ** 8,
            .next_free = 1,
        };
    }

    /// Adds the given segment descriptor to the GDT, returning the segment selector.
    ///
    /// Panics if the GDT has no free entries left.
    pub inline fn add_entry(self: *GlobalDescriptorTable, entry: Descriptor) SegmentSelector {
        switch (entry) {
            .UserSegment => |value| {
                const rpl = if (value & Descriptor.DPL_RING_3 != 0) PrivilegeLevel.Ring3 else PrivilegeLevel.Ring0;
                return SegmentSelector.new(self.push(value), rpl);
            },
            .SystemSegment => |systemSegmentData| {
                const index = self.push(systemSegmentData.low);
                _ = self.push(systemSegmentData.high);
                return SegmentSelector.new(index, PrivilegeLevel.Ring0);
            },
        }
    }

    /// Loads the GDT in the CPU using the `lgdt` instruction. This does **not** alter any of the
    /// segment registers; you **must** (re)load them yourself using the appropriate
    /// functions: `instructions.segmentation.load_ss`, `instructions.segmentation.set_cs`
    pub inline fn load(self: *GlobalDescriptorTable) void {
        const ptr = structures.DescriptorTablePointer{
            .base = @ptrToInt(&self.table),
            .limit = @as(u64, self.table.len * @sizeOf(u64) - 1),
        };

        instructions.tables.lgdt(&ptr);
    }

    inline fn push(self: *GlobalDescriptorTable, value: u64) u16 {
        if (self.next_free < self.table.len) {
            const index = self.next_free;
            self.table[index] = value;
            self.next_free += 1;
            return index;
        }

        @panic("GDT full");
    }
};

test "GlobalDescriptorTable" {
    var gdt = GlobalDescriptorTable.new();
    _ = gdt.add_entry(kernel_code_segment());
    _ = gdt.add_entry(user_code_segment());
    _ = gdt.add_entry(user_data_segment());
}

/// Creates a segment descriptor for a long mode kernel code segment.
pub inline fn kernel_code_segment() Descriptor {
    const flags: u64 = Descriptor.USER_SEGMENT | Descriptor.PRESENT | Descriptor.EXECUTABLE | Descriptor.LONG_MODE;
    return Descriptor{ .UserSegment = flags };
}

/// Creates a segment descriptor for a long mode ring 3 data segment.
pub inline fn user_data_segment() Descriptor {
    const flags: u64 = Descriptor.USER_SEGMENT | Descriptor.PRESENT | Descriptor.WRITABLE | Descriptor.DPL_RING_3;
    return Descriptor{ .UserSegment = flags };
}

/// Creates a segment descriptor for a long mode ring 3 code segment.
pub inline fn user_code_segment() Descriptor {
    const flags: u64 = Descriptor.USER_SEGMENT | Descriptor.PRESENT | Descriptor.EXECUTABLE | Descriptor.LONG_MODE | Descriptor.DPL_RING_3;
    return Descriptor{ .UserSegment = flags };
}

// TODO: Waiting on TaskStateSegment
// Creates a TSS system descriptor for the given TSS.
// pub inline fn tss_segment(tss: TaskStateSegment) Descriptor {
//
// }

/// A 64-bit mode segment descriptor
///
/// Segmentation is no longer supported in 64-bit mode, so most of the descriptor
/// contents are ignored.
pub const Descriptor = union(enum) {
    /// For data segments, this flag sets the segment as writable. Ignored for code segments.
    pub const WRITABLE: u64 = 1 << 41;
    /// Marks a code segment as “conforming”. This influences the privilege checks that
    /// occur on control transfers.
    pub const CONFORMING: u64 = 1 << 42;
    /// This flag must be set for code segments.
    pub const EXECUTABLE: u64 = 1 << 43;
    /// This flag must be set for user segments (in contrast to system segments).
    pub const USER_SEGMENT: u64 = 1 << 44;
    /// Must be set for any segment, causes a segment not present exception if not set.
    pub const PRESENT: u64 = 1 << 47;
    /// Must be set for long mode code segments.
    pub const LONG_MODE: u64 = 1 << 53;
    /// The DPL for this descriptor is Ring 3
    pub const DPL_RING_3: u64 = 1 << 45;

    /// Descriptor for a code or data segment.
    ///
    /// Since segmentation is no longer supported in 64-bit mode, almost all of
    /// code and data descriptors is ignored. Only some flags are still use
    UserSegment: u64,
    /// A system segment descriptor such as a LDT or TSS descriptor.
    SystemSegment: SystemSegmentData,

    pub const SystemSegmentData = packed struct {
        low: u64,
        high: u64,
    };
};

test "SystemSegmentData" {
    std.testing.expectEqual(@bitSizeOf(u64) * 2, @bitSizeOf(Descriptor.SystemSegmentData));
    std.testing.expectEqual(@sizeOf(u64) * 2, @sizeOf(Descriptor.SystemSegmentData));
}

test "" {
    std.meta.refAllDecls(@This());
}
