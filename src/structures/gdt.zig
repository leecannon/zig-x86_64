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
    pub inline fn init(index: u16, rpl: PrivilegeLevel) SegmentSelector {
        return SegmentSelector{ .selector = index << 3 | @as(u16, @enumToInt(rpl)) };
    }

    /// Returns the GDT index.
    pub inline fn gdt_index(self: SegmentSelector) u16 {
        return self.selector >> 3;
    }

    /// Returns the requested privilege level.
    pub inline fn get_rpl(self: SegmentSelector) !PrivilegeLevel {
        return try PrivilegeLevel.from_u16(get_bits(self.selector, 0, 2));
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

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "SegmentSelector" {
    var a = SegmentSelector.init(1, .Ring0);
    testing.expectEqual(@as(u16, 1), a.gdt_index());
    testing.expectEqual(PrivilegeLevel.Ring0, try a.get_rpl());
    a.set_rpl(.Ring3);
    testing.expectEqual(@as(u16, 1), a.gdt_index());
    testing.expectEqual(PrivilegeLevel.Ring3, try a.get_rpl());
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
/// // Construct a structures.tss.TaskStateSegment
/// // Fill it with the stacks, etc you want
/// var tss: structures.tss.TaskStateSegment = SOMETHING_HERE
///
/// var gdt = GlobalDescriptorTable.init();
/// const kernel_code_segment = gdt.add_entry(kernel_code_segment());
/// const kernel_data_segment = gdt.add_entry(kernel_data_segment());
/// const user_code_segment = gdt.add_entry(user_code_segment());
/// const user_data_segment = gdt.add_entry(user_data_segment());
/// const tss_segment = gdt.add_entry(tss_segment(&tss)); // Pointer to structures.tss.TaskStateSegment
/// gdt.load()
///
/// instructions.segmentation.set_cs(kernel_code_segment);
/// instructions.segmentation.load_ds(kernel_data_segment);
/// instructions.segmentation.load_es(kernel_data_segment);
/// instructions.segmentation.load_fs(kernel_data_segment);
/// instructions.segmentation.load_gs(kernel_data_segment);
/// instructions.segmentation.load_ss(kernel_data_segment);
///
/// instructions.tables.load_tss(tss_segment);
///
/// ```
pub const GlobalDescriptorTable = struct {
    table: [8]u64,
    next_free: u16,

    /// Creates an empty GDT.
    pub inline fn init() GlobalDescriptorTable {
        return GlobalDescriptorTable{
            .table = [_]u64{0} ** 8,
            .next_free = 1,
        };
    }

    /// Adds the given segment descriptor to the GDT, returning the segment selector.
    ///
    /// Panics if the GDT has no free entries left.
    pub fn add_entry(self: *GlobalDescriptorTable, entry: Descriptor) SegmentSelector {
        switch (entry) {
            .UserSegment => |value| {
                const rpl = if (value & Descriptor.DPL_RING_3 != 0) PrivilegeLevel.Ring3 else PrivilegeLevel.Ring0;
                return SegmentSelector.init(self.push(value), rpl);
            },
            .SystemSegment => |systemSegmentData| {
                const index = self.push(systemSegmentData.low);
                _ = self.push(systemSegmentData.high);
                return SegmentSelector.init(index, PrivilegeLevel.Ring0);
            },
        }
    }

    /// Loads the GDT in the CPU using the `lgdt` instruction. This does **not** alter any of the
    /// segment registers; you **must** (re)load them yourself using the appropriate
    /// functions: `instructions.segmentation.load_ss`, `instructions.segmentation.set_cs`
    pub fn load(self: *GlobalDescriptorTable) void {
        const ptr = structures.DescriptorTablePointer{
            .base = @ptrToInt(&self.table),
            .limit = @as(u16, self.table.len * @sizeOf(u64) - 1),
        };

        instructions.tables.lgdt(&ptr);
    }

    fn push(self: *GlobalDescriptorTable, value: u64) u16 {
        if (self.next_free < self.table.len) {
            const index = self.next_free;
            self.table[index] = value;
            self.next_free += 1;
            return index;
        }

        @panic("GDT full");
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "GlobalDescriptorTable" {
    var gdt = GlobalDescriptorTable.init();
    _ = gdt.add_entry(kernel_code_segment());
    _ = gdt.add_entry(user_code_segment());
    _ = gdt.add_entry(user_data_segment());
}

/// Creates a segment descriptor for a 64-bit kernel code segment. Suitable
/// for use with `syscall` or 64-bit `sysenter`.
pub inline fn kernel_code_segment() Descriptor {
    return Descriptor{ .UserSegment = Descriptor.KERNEL_CODE64 };
}

pub inline fn kernel_data_segment() Descriptor {
    return Descriptor{ .UserSegment = Descriptor.KERNEL_DATA };
}

/// Creates a segment descriptor for a ring 3 data segment (32-bit or
/// 64-bit). Suitable for use with `sysret` or `sysexit`.
pub inline fn user_data_segment() Descriptor {
    return Descriptor{ .UserSegment = Descriptor.USER_DATA };
}

/// Creates a segment descriptor for a 64-bit ring 3 code segment. Suitable
/// for use with `sysret` or `sysexit`.
pub inline fn user_code_segment() Descriptor {
    return Descriptor{ .UserSegment = Descriptor.USER_CODE64 };
}

/// Creates a TSS system descriptor for the given TSS.
pub fn tss_segment(tss: *structures.tss.TaskStateSegment) Descriptor {
    const ptr = @ptrToInt(tss);

    var low = Descriptor.PRESENT;
    // base
    set_bits(&low, 16, 24, get_bits(ptr, 0, 24));
    set_bits(&low, 56, 8, get_bits(ptr, 24, 8));
    // limit (the `-1` in needed since the bound is inclusive)
    set_bits(&low, 0, 16, @as(u64, @sizeOf(structures.tss.TaskStateSegment) - 1));
    // type (0b1001 = available 64-bit tss)
    set_bits(&low, 40, 4, 0b1001);

    var high: u64 = 0;
    set_bits(&high, 0, 32, get_bits(ptr, 32, 32));

    return Descriptor{
        .SystemSegment = Descriptor.SystemSegmentData{
            .low = low,
            .high = high,
        },
    };
}

/// A 64-bit mode segment descriptor
///
/// Segmentation is no longer supported in 64-bit mode, so most of the descriptor
/// contents are ignored.
pub const Descriptor = union(enum) {
    /// Set by the processor if this segment has been accessed. Only cleared by software.
    pub const ACCESSED: u64 = 1 << 40;

    /// For 32-bit data segments, sets the segment as writable. For 32-bit code segments,
    /// sets the segment as _readable_. In 64-bit mode, ignored for all segments.
    pub const WRITABLE: u64 = 1 << 41;

    /// For code segments, sets the segment as “conforming”, influencing the
    /// privilege checks that occur on control transfers. For 32-bit data segments,
    /// sets the segment as "expand down". In 64-bit mode, ignored for data segments.
    pub const CONFORMING: u64 = 1 << 42;

    /// This flag must be set for code segments and unset for data segments.
    pub const EXECUTABLE: u64 = 1 << 43;

    /// This flag must be set for user segments (in contrast to system segments).
    pub const USER_SEGMENT: u64 = 1 << 44;

    /// The DPL for this descriptor is Ring 3. In 64-bit mode, ignored for data segments.
    pub const DPL_RING_3: u64 = 3 << 45;

    /// Must be set for any segment, causes a segment not present exception if not set.
    pub const PRESENT: u64 = 1 << 47;

    /// Available for use by the Operating System
    pub const AVAILABLE: u64 = 1 << 52;

    /// Must be set for 64-bit code segments, unset otherwise.
    pub const LONG_MODE: u64 = 1 << 53;

    /// Use 32-bit (as opposed to 16-bit) operands. If [`LONG_MODE`] is set,
    /// this must be unset. In 64-bit mode, ignored for data segments.
    pub const DEFAULT_SIZE: u64 = 1 << 54;

    /// Limit field is scaled by 4096 bytes. In 64-bit mode, ignored for all segments.
    pub const GRANULARITY: u64 = 1 << 55;

    /// Bits 0..=15 of the limit field (ignored in 64-bit mode)
    pub const LIMIT_0_15: u64 = 0xFFFF;
    /// Bits 16..=19 of the limit field (ignored in 64-bit mode)
    pub const LIMIT_16_19: u64 = 0xF << 48;
    /// Bits 0..=23 of the base field (ignored in 64-bit mode, except for fs and gs)
    pub const BASE_0_23: u64 = 0xFF_FFFF << 16;
    /// Bits 24..=31 of the base field (ignored in 64-bit mode, except for fs and gs)
    pub const BASE_24_31: u64 = 0xFF << 56;

    /// Flags that we set for all our default segments
    pub const COMMON: u64 = USER_SEGMENT | PRESENT | WRITABLE | ACCESSED | LIMIT_0_15 | LIMIT_16_19 | GRANULARITY;

    /// A kernel data segment (64-bit or flat 32-bit)
    pub const KERNEL_DATA: u64 = COMMON | DEFAULT_SIZE;
    /// A flat 32-bit kernel code segment
    pub const KERNEL_CODE32: u64 = COMMON | EXECUTABLE | DEFAULT_SIZE;
    /// A 64-bit kernel code segment
    pub const KERNEL_CODE64: u64 = COMMON | EXECUTABLE | LONG_MODE;

    /// A user data segment (64-bit or flat 32-bit)
    pub const USER_DATA: u64 = KERNEL_DATA | DPL_RING_3;
    /// A flat 32-bit user code segment
    pub const USER_CODE32: u64 = KERNEL_CODE32 | DPL_RING_3;
    /// A 64-bit user code segment
    pub const USER_CODE64: u64 = KERNEL_CODE64 | DPL_RING_3;

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

    test "Descriptors match linux" {
        // Make sure our defaults match the ones used by the Linux kernel.
        // Constants pulled from an old version of arch/x86/kernel/cpu/common.c
        std.testing.expectEqual(0x00af9b000000ffff, Descriptor.KERNEL_CODE64);
        std.testing.expectEqual(0x00cf9b000000ffff, Descriptor.KERNEL_CODE32);
        std.testing.expectEqual(0x00cf93000000ffff, Descriptor.KERNEL_DATA);
        std.testing.expectEqual(0x00affb000000ffff, Descriptor.USER_CODE64);
        std.testing.expectEqual(0x00cffb000000ffff, Descriptor.USER_CODE32);
        std.testing.expectEqual(0x00cff3000000ffff, Descriptor.USER_DATA);
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

test "SystemSegmentData" {
    std.testing.expectEqual(@bitSizeOf(u64) * 2, @bitSizeOf(Descriptor.SystemSegmentData));
    std.testing.expectEqual(@sizeOf(u64) * 2, @sizeOf(Descriptor.SystemSegmentData));
}

test "" {
    std.testing.refAllDecls(@This());
}
