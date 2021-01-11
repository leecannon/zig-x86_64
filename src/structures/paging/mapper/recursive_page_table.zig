usingnamespace @import("../../../common.zig");

const Mapper = paging.Mapper;
const paging = structures.paging;

pub const InvalidPageTable = error{
    /// The given page table was not at an recursive address.
    ///
    /// The page table address must be of the form `0o_xxx_xxx_xxx_xxx_0000` where `xxx`
    /// is the recursive entry.
    NotRecursive,

    /// The given page table was not active on the CPU.
    ///
    /// The recursive page table design requires that the given level 4 table is active
    /// on the CPU because otherwise it's not possible to access the other page tables
    /// through recursive memory addresses.
    NotActive,
};

/// A recursive page table is a last level page table with an entry mapped to the table itself.
///
/// This recursive mapping allows accessing all page tables in the hierarchy:
///
/// - To access the level 4 page table, we “loop“ (i.e. follow the recursively mapped entry) four
///   times.
/// - To access a level 3 page table, we “loop” three times and then use the level 4 index.
/// - To access a level 2 page table, we “loop” two times, then use the level 4 index, then the
///   level 3 index.
/// - To access a level 1 page table, we “loop” once, then use the level 4 index, then the
///   level 3 index, then the level 2 index.
///
/// This struct implements the `Mapper` trait.
///
/// The page table flags `PRESENT` and `WRITABLE` are always set for higher level page table
/// entries, even if not specified, because the design of the recursive page table requires it.
pub const RecursivePageTable = struct {
    mapper: Mapper,
    level_4_table: *paging.PageTable,
    recursive_index: paging.PageTableIndex,

    /// Creates a new RecursivePageTable from the passed level 4 PageTable.
    ///
    /// The page table must be recursively mapped, that means:
    ///
    /// - The page table must have one recursive entry, i.e. an entry that points to the table
    ///   itself.
    ///     - The reference must use that “loop”, i.e. be of the form `0o_xxx_xxx_xxx_xxx_0000`
    ///       where `xxx` is the recursive entry.
    /// - The page table must be active, i.e. the CR3 register must contain its physical address.
    ///
    /// Otherwise a `RecursivePageTableCreationError` is returned.
    pub fn init(table: *paging.PageTable) InvalidPageTable!RecursivePageTable {
        const page = paging.Page.containingAddress(VirtAddr.initPanic(@ptrToInt(table)));
        const recursive_index = page.p4Index();
        const recursive_index_value = recursive_index.value;

        if (page.p3Index().value != recursive_index_value or
            page.p2Index().value != recursive_index_value or
            page.p1Index().value != recursive_index_value)
        {
            return InvalidPageTable.NotRecursive;
        }

        const recursive_index_frame = table.getAtIndex(recursive_index).getFrame() catch return InvalidPageTable.NotRecursive;
        if (registers.control.Cr3.read().physFrame.start_address.value != recursive_index_frame.start_address.value) {
            return InvalidPageTable.NotActive;
        }

        return RecursivePageTable{
            .mapper = makeMapper(),
            .level_4_table = table,
            .recursive_index = recursive_index,
        };
    }

    /// Creates a new RecursivePageTable without performing any checks.
    ///
    /// ## Safety
    ///
    /// The given page table must be a level 4 page table that is active in the
    /// CPU (i.e. loaded in the CR3 register). The `recursive_index` parameter
    /// must be the index of the recursively mapped entry of that page table.
    pub fn initUnchecked(table: *paging.PageTable, recursive_index: paging.PageTableIndex) RecursivePageTable {
        return .{
            .mapper = makeMapper(),
            .level_4_table = table,
            .recursive_index = recursive_index,
        };
    }

    inline fn getSelfPtr(mapper: *Mapper) *RecursivePageTable {
        return @fieldParentPtr(RecursivePageTable, "mapper", mapper);
    }

    fn mapToWithTableFlags1GiB(
        mapper: *Mapper,
        page: paging.Page1GiB,
        frame: paging.PhysFrame1GiB,
        flags: paging.PageTableFlags,
        parent_table_flags: paging.PageTableFlags,
        frame_allocator: *paging.FrameAllocator,
    ) paging.MapToError!paging.MapperFlush1GiB {
        var self = getSelfPtr(mapper);

        const p3 = try createNextTable(
            self.level_4_table.getAtIndex(page.p4Index()),
            p3Page(
                .Size1GiB,
                page,
                self.recursive_index,
            ),
            parent_table_flags,
            frame_allocator,
        );

        var entry = p3.getAtIndex(page.p3Index());
        if (!entry.isUnused()) return paging.MapToError.PageAlreadyMapped;

        entry.setAddr(frame.start_address);

        var new_flags = flags;
        new_flags.value |= paging.PageTableFlags.HUGE_PAGE;

        entry.setFlags(new_flags);

        return paging.MapperFlush1GiB.init(page);
    }

    fn unmap1GiB(
        mapper: *Mapper,
        page: paging.Page1GiB,
    ) paging.UnmapError!paging.UnmapResult1GiB {
        var self = getSelfPtr(mapper);

        _ = self.level_4_table.getAtIndex(page.p4Index()).getFrame() catch |err| switch (err) {
            paging.FrameError.FrameNotPresent => return paging.UnmapError.PageNotMapped,
            paging.FrameError.HugeFrame => return paging.UnmapError.ParentEntryHugePage,
        };

        const p3 = p3Ptr(.Size1GiB, page, self.recursive_index);

        const p3_entry = p3.getAtIndex(page.p3Index());
        const flags = p3_entry.getFlags();

        if (flags.value & paging.PageTableFlags.PRESENT == 0) return paging.UnmapError.PageNotMapped;
        if (flags.value & paging.PageTableFlags.HUGE_PAGE == 0) return paging.UnmapError.ParentEntryHugePage;

        const frame = paging.PhysFrame1GiB.fromStartAddress(p3_entry.getAddr()) catch |err| return paging.UnmapError.InvalidFrameAddress;

        p3_entry.setUnused();

        return paging.UnmapResult1GiB{
            .frame = frame,
            .flush = paging.MapperFlush1GiB.init(page),
        };
    }

    fn updateFlags1GiB(
        mapper: *Mapper,
        page: paging.Page1GiB,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlush1GiB {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return paging.FlagUpdateError.PageNotMapped;
        }

        const p3 = p3Ptr(.Size1GiB, page, self.recursive_index);

        var p3_entry = p3.getAtIndex(page.p3Index());

        if (p3_entry.isUnused()) return paging.FlagUpdateError.PageNotMapped;

        var new_flags = flags;
        new_flags.value |= paging.PageTableFlags.HUGE_PAGE;
        p3_entry.setFlags(new_flags);

        return paging.MapperFlush1GiB.init(page);
    }

    fn setFlagsP4Entry1GiB(
        mapper: *Mapper,
        page: paging.Page1GiB,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlushAll {
        var self = getSelfPtr(mapper);

        const p4_entry = self.level_4_table.getAtIndex(page.p4Index());
        if (p4_entry.isUnused()) return paging.FlagUpdateError.PageNotMapped;

        p4_entry.setFlags(flags);
        return paging.MapperFlushAll{};
    }

    fn translatePage1GiB(
        mapper: *Mapper,
        page: paging.Page1GiB,
    ) paging.TranslateError!paging.PhysFrame1GiB {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return paging.TranslateError.NotMapped;
        }

        const p3 = p3Ptr(.Size1GiB, page, self.recursive_index);

        const p3_entry = p3.getAtIndex(page.p3Index());

        if (p3_entry.isUnused()) return paging.TranslateError.NotMapped;

        return paging.PhysFrame1GiB.fromStartAddress(p3_entry.getAddr()) catch |err| return paging.TranslateError.InvalidFrameAddress;
    }

    fn mapToWithTableFlags2MiB(
        mapper: *Mapper,
        page: paging.Page2MiB,
        frame: paging.PhysFrame2MiB,
        flags: paging.PageTableFlags,
        parent_table_flags: paging.PageTableFlags,
        frame_allocator: *paging.FrameAllocator,
    ) paging.MapToError!paging.MapperFlush2MiB {
        var self = getSelfPtr(mapper);

        const p3 = try createNextTable(
            self.level_4_table.getAtIndex(page.p4Index()),
            p3Page(
                .Size2MiB,
                page,
                self.recursive_index,
            ),
            parent_table_flags,
            frame_allocator,
        );

        const p2 = try createNextTable(
            p3.getAtIndex(page.p3Index()),
            p2Page(
                .Size2MiB,
                page,
                self.recursive_index,
            ),
            parent_table_flags,
            frame_allocator,
        );

        var entry = p2.getAtIndex(page.p2Index());
        if (!entry.isUnused()) return paging.MapToError.PageAlreadyMapped;

        entry.setAddr(frame.start_address);

        var new_flags = flags;
        new_flags.value |= paging.PageTableFlags.HUGE_PAGE;

        entry.setFlags(new_flags);

        return paging.MapperFlush2MiB.init(page);
    }

    fn unmap2MiB(
        mapper: *Mapper,
        page: paging.Page2MiB,
    ) paging.UnmapError!paging.UnmapResult2MiB {
        var self = getSelfPtr(mapper);

        _ = self.level_4_table.getAtIndex(page.p4Index()).getFrame() catch |err| switch (err) {
            paging.FrameError.FrameNotPresent => return paging.UnmapError.PageNotMapped,
            paging.FrameError.HugeFrame => return paging.UnmapError.ParentEntryHugePage,
        };

        const p3 = p3Ptr(.Size2MiB, page, self.recursive_index);
        const p3_entry = p3.getAtIndex(page.p3Index());

        _ = p3_entry.getFrame() catch |err| switch (err) {
            paging.FrameError.FrameNotPresent => return paging.UnmapError.PageNotMapped,
            paging.FrameError.HugeFrame => return paging.UnmapError.ParentEntryHugePage,
        };

        const p2 = p2Ptr(.Size2MiB, page, self.recursive_index);

        const p2_entry = p2.getAtIndex(page.p2Index());
        const flags = p2_entry.getFlags();

        if (flags.value & paging.PageTableFlags.PRESENT == 0) return paging.UnmapError.PageNotMapped;
        if (flags.value & paging.PageTableFlags.HUGE_PAGE == 0) return paging.UnmapError.ParentEntryHugePage;

        const frame = paging.PhysFrame2MiB.fromStartAddress(p2_entry.getAddr()) catch |err| return paging.UnmapError.InvalidFrameAddress;

        p2_entry.setUnused();

        return paging.UnmapResult2MiB{
            .frame = frame,
            .flush = paging.MapperFlush2MiB.init(page),
        };
    }

    fn updateFlags2MiB(
        mapper: *Mapper,
        page: paging.Page2MiB,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlush2MiB {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return paging.FlagUpdateError.PageNotMapped;
        }

        const p3 = p3Ptr(.Size2MiB, page, self.recursive_index);

        var p3_entry = p3.getAtIndex(page.p3Index());

        if (p3_entry.isUnused()) return paging.FlagUpdateError.PageNotMapped;

        const p2 = p2Ptr(.Size2MiB, page, self.recursive_index);

        var p2_entry = p2.getAtIndex(page.p2Index());

        if (p2_entry.isUnused()) return paging.FlagUpdateError.PageNotMapped;

        var new_flags = flags;
        new_flags.value |= paging.PageTableFlags.HUGE_PAGE;
        p2_entry.setFlags(new_flags);

        return paging.MapperFlush2MiB.init(page);
    }

    fn setFlagsP4Entry2MiB(
        mapper: *Mapper,
        page: paging.Page2MiB,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlushAll {
        var self = getSelfPtr(mapper);

        const p4_entry = self.level_4_table.getAtIndex(page.p4Index());
        if (p4_entry.isUnused()) return paging.FlagUpdateError.PageNotMapped;
        p4_entry.setFlags(flags);
        return paging.MapperFlushAll{};
    }

    fn setFlagsP3Entry2MiB(
        mapper: *Mapper,
        page: paging.Page2MiB,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlushAll {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return paging.FlagUpdateError.PageNotMapped;
        }

        const p3 = p3Ptr(.Size2MiB, page, self.recursive_index);

        const p3_entry = p3.getAtIndex(page.p3Index());
        if (p3_entry.isUnused()) return paging.FlagUpdateError.PageNotMapped;
        p3_entry.setFlags(flags);
        return paging.MapperFlushAll{};
    }

    fn translatePage2MiB(
        mapper: *Mapper,
        page: paging.Page2MiB,
    ) paging.TranslateError!paging.PhysFrame2MiB {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return paging.TranslateError.NotMapped;
        }

        const p3 = p3Ptr(.Size2MiB, page, self.recursive_index);

        const p3_entry = p3.getAtIndex(page.p3Index());

        if (p3_entry.isUnused()) return paging.TranslateError.NotMapped;

        const p2 = p2Ptr(.Size2MiB, page, self.recursive_index);

        const p2_entry = p2.getAtIndex(page.p2Index());

        if (p2_entry.isUnused()) return paging.TranslateError.NotMapped;

        return paging.PhysFrame2MiB.fromStartAddress(p2_entry.getAddr()) catch |err| return paging.TranslateError.InvalidFrameAddress;
    }

    fn mapToWithTableFlags(
        mapper: *Mapper,
        page: paging.Page,
        frame: paging.PhysFrame,
        flags: paging.PageTableFlags,
        parent_table_flags: paging.PageTableFlags,
        frame_allocator: *paging.FrameAllocator,
    ) paging.MapToError!paging.MapperFlush {
        var self = getSelfPtr(mapper);

        const p3 = try createNextTable(
            self.level_4_table.getAtIndex(page.p4Index()),
            p3Page(
                .Size4KiB,
                page,
                self.recursive_index,
            ),
            parent_table_flags,
            frame_allocator,
        );

        const p2 = try createNextTable(
            p3.getAtIndex(page.p3Index()),
            p2Page(
                .Size4KiB,
                page,
                self.recursive_index,
            ),
            parent_table_flags,
            frame_allocator,
        );

        const p1 = try createNextTable(
            p2.getAtIndex(page.p2Index()),
            p1Page(
                .Size4KiB,
                page,
                self.recursive_index,
            ),
            parent_table_flags,
            frame_allocator,
        );

        var entry = p1.getAtIndex(page.p1Index());
        if (!entry.isUnused()) return paging.MapToError.PageAlreadyMapped;

        entry.setAddr(frame.start_address);
        entry.setFlags(flags);

        return paging.MapperFlush.init(page);
    }

    fn unmap(
        mapper: *Mapper,
        page: paging.Page,
    ) paging.UnmapError!paging.UnmapResult {
        var self = getSelfPtr(mapper);

        _ = self.level_4_table.getAtIndex(page.p4Index()).getFrame() catch |err| switch (err) {
            paging.FrameError.FrameNotPresent => return paging.UnmapError.PageNotMapped,
            paging.FrameError.HugeFrame => return paging.UnmapError.ParentEntryHugePage,
        };

        const p3 = p3Ptr(.Size4KiB, page, self.recursive_index);
        const p3_entry = p3.getAtIndex(page.p3Index());

        _ = p3_entry.getFrame() catch |err| switch (err) {
            paging.FrameError.FrameNotPresent => return paging.UnmapError.PageNotMapped,
            paging.FrameError.HugeFrame => return paging.UnmapError.ParentEntryHugePage,
        };

        const p2 = p2Ptr(.Size4KiB, page, self.recursive_index);
        const p2_entry = p2.getAtIndex(page.p2Index());

        _ = p2_entry.getFrame() catch |err| switch (err) {
            paging.FrameError.FrameNotPresent => return paging.UnmapError.PageNotMapped,
            paging.FrameError.HugeFrame => return paging.UnmapError.ParentEntryHugePage,
        };

        const p1 = p2Ptr(.Size4KiB, page, self.recursive_index);
        const p1_entry = p1.getAtIndex(page.p1Index());

        const frame = p1_entry.getFrame() catch |err| switch (err) {
            paging.FrameError.FrameNotPresent => return paging.UnmapError.PageNotMapped,
            paging.FrameError.HugeFrame => return paging.UnmapError.ParentEntryHugePage,
        };

        p1_entry.setUnused();

        return paging.UnmapResult{
            .frame = frame,
            .flush = paging.MapperFlush.init(page),
        };
    }

    fn updateFlags(
        mapper: *Mapper,
        page: paging.Page,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlush {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return paging.FlagUpdateError.PageNotMapped;
        }

        const p3 = p3Ptr(.Size4KiB, page, self.recursive_index);

        var p3_entry = p3.getAtIndex(page.p3Index());

        if (p3_entry.isUnused()) return paging.FlagUpdateError.PageNotMapped;

        const p2 = p2Ptr(.Size4KiB, page, self.recursive_index);

        var p2_entry = p2.getAtIndex(page.p2Index());

        if (p2_entry.isUnused()) return paging.FlagUpdateError.PageNotMapped;

        const p1 = p1Ptr(.Size4KiB, page, self.recursive_index);

        var p1_entry = p1.getAtIndex(page.p1Index());

        if (p1_entry.isUnused()) return paging.FlagUpdateError.PageNotMapped;

        p1_entry.setFlags(flags);

        return paging.MapperFlush.init(page);
    }

    fn setFlagsP4Entry(
        mapper: *Mapper,
        page: paging.Page,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlushAll {
        var self = getSelfPtr(mapper);

        const p4_entry = self.level_4_table.getAtIndex(page.p4Index());
        if (p4_entry.isUnused()) return paging.FlagUpdateError.PageNotMapped;
        p4_entry.setFlags(flags);
        return paging.MapperFlushAll{};
    }

    fn setFlagsP3Entry(
        mapper: *Mapper,
        page: paging.Page,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlushAll {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return paging.FlagUpdateError.PageNotMapped;
        }

        const p3 = p3Ptr(.Size4KiB, page, self.recursive_index);

        const p3_entry = p3.getAtIndex(page.p3Index());
        if (p3_entry.isUnused()) return paging.FlagUpdateError.PageNotMapped;

        p3_entry.setFlags(flags);
        return paging.MapperFlushAll{};
    }

    fn setFlagsP2Entry(
        mapper: *Mapper,
        page: paging.Page,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlushAll {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return paging.FlagUpdateError.PageNotMapped;
        }

        const p3 = p3Ptr(.Size4KiB, page, self.recursive_index);

        const p3_entry = p3.getAtIndex(page.p3Index());
        if (p3_entry.isUnused()) return paging.FlagUpdateError.PageNotMapped;

        const p2 = p2Ptr(.Size4KiB, page, self.recursive_index);

        const p2_entry = p2.getAtIndex(page.p2Index());
        if (p2_entry.isUnused()) return paging.FlagUpdateError.PageNotMapped;

        p2_entry.setFlags(flags);
        return paging.MapperFlushAll{};
    }

    fn translatePage(
        mapper: *Mapper,
        page: paging.Page,
    ) paging.TranslateError!paging.PhysFrame {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return paging.TranslateError.NotMapped;
        }

        const p3 = p3Ptr(.Size4KiB, page, self.recursive_index);

        const p3_entry = p3.getAtIndex(page.p3Index());

        if (p3_entry.isUnused()) return paging.TranslateError.NotMapped;

        const p2 = p2Ptr(.Size4KiB, page, self.recursive_index);

        const p2_entry = p2.getAtIndex(page.p2Index());

        if (p2_entry.isUnused()) return paging.TranslateError.NotMapped;

        const p1 = p1Ptr(.Size4KiB, page, self.recursive_index);

        const p1_entry = p1.getAtIndex(page.p1Index());

        if (p1_entry.isUnused()) return paging.TranslateError.NotMapped;

        return paging.PhysFrame.fromStartAddress(p1_entry.getAddr()) catch |err| return paging.TranslateError.InvalidFrameAddress;
    }

    fn translate(
        mapper: *Mapper,
        addr: VirtAddr,
    ) paging.TranslateError!paging.TranslateResult {
        var self = getSelfPtr(mapper);
        const page = paging.Page.containingAddress(addr);

        const p4_entry = self.level_4_table.getAtIndex(addr.p4Index());
        if (p4_entry.isUnused()) {
            return paging.TranslateError.NotMapped;
        }
        if (p4_entry.getFlags().value & paging.PageTableFlags.HUGE_PAGE != 0) {
            @panic("level 4 entry has huge page bit set");
        }

        const p3 = p3Ptr(.Size4KiB, page, self.recursive_index);

        const p3_entry = p3.getAtIndex(page.p3Index());
        if (p3_entry.isUnused()) return paging.TranslateError.NotMapped;

        const p3_flags = p3_entry.getFlags();
        if (p3_flags.value & paging.PageTableFlags.HUGE_PAGE != 0) {
            return paging.TranslateResult{
                .Frame1GiB = .{
                    .frame = paging.PhysFrame1GiB.containingAddress(p3_entry.getAddr()),
                    .offset = addr.value & 0o777_777_7777,
                    .flags = p3_flags,
                },
            };
        }

        const p2 = p2Ptr(.Size4KiB, page, self.recursive_index);

        const p2_entry = p2.getAtIndex(addr.p2Index());
        if (p2_entry.isUnused()) return paging.TranslateError.NotMapped;

        const p2_flags = p2_entry.getFlags();
        if (p2_flags.value & paging.PageTableFlags.HUGE_PAGE != 0) {
            return paging.TranslateResult{
                .Frame2MiB = .{
                    .frame = paging.PhysFrame2MiB.containingAddress(p2_entry.getAddr()),
                    .offset = addr.value & 0o777_7777,
                    .flags = p2_flags,
                },
            };
        }

        const p1 = p2Ptr(.Size4KiB, page, self.recursive_index);

        const p1_entry = p1.getAtIndex(addr.p1Index());
        if (p1_entry.isUnused()) return paging.TranslateError.NotMapped;

        const p1_flags = p1_entry.getFlags();
        if (p1_flags.value & paging.PageTableFlags.HUGE_PAGE != 0) {
            @panic("level 1 entry has huge page bit set");
        }

        const frame = paging.PhysFrame.fromStartAddress(p1_entry.getAddr()) catch |err| return paging.TranslateError.InvalidFrameAddress;

        return paging.TranslateResult{
            .Frame4KiB = .{
                .frame = frame,
                .offset = @as(u64, addr.pageOffset().value),
                .flags = p1_flags,
            },
        };
    }

    fn makeMapper() Mapper {
        return .{
            .impl_mapToWithTableFlags1GiB = mapToWithTableFlags1GiB,
            .impl_unmap1GiB = unmap1GiB,
            .impl_updateFlags1GiB = updateFlags1GiB,
            .impl_setFlagsP4Entry1GiB = setFlagsP4Entry1GiB,
            .impl_translatePage1GiB = translatePage1GiB,
            .impl_mapToWithTableFlags2MiB = mapToWithTableFlags2MiB,
            .impl_unmap2MiB = unmap2MiB,
            .impl_updateFlags2MiB = updateFlags2MiB,
            .impl_setFlagsP4Entry2MiB = setFlagsP4Entry2MiB,
            .impl_setFlagsP3Entry2MiB = setFlagsP3Entry2MiB,
            .impl_translatePage2MiB = translatePage2MiB,
            .impl_mapToWithTableFlags = mapToWithTableFlags,
            .impl_unmap = unmap,
            .impl_updateFlags = updateFlags,
            .impl_setFlagsP4Entry = setFlagsP4Entry,
            .impl_setFlagsP3Entry = setFlagsP3Entry,
            .impl_setFlagsP2Entry = setFlagsP2Entry,
            .impl_translatePage = translatePage,
            .impl_translate = translate,
        };
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

/// Internal helper function to create the page table of the next level if needed.
///
/// If the passed entry is unused, a new frame is allocated from the given allocator, zeroed,
/// and the entry is updated to that address. If the passed entry is already mapped, the next
/// table is returned directly.
///
/// The page table flags `PRESENT` and `WRITABLE` are always set for higher level page table
/// entries, even if not specified in the `insert_flags`, because the design of the
/// recursive page table requires it.
///
/// The `next_page_table` page must be the page of the next page table in the hierarchy.
///
/// Returns `MapToError::FrameAllocationFailed` if the entry is unused and the allocator
/// returned `None`. Returns `MapToError::ParentEntryHugePage` if the `HUGE_PAGE` flag is set
/// in the passed entry.
fn createNextTable(
    entry: *paging.PageTableEntry,
    nextTablePage: paging.Page,
    insertFlags: paging.PageTableFlags,
    frameAllocator: *paging.FrameAllocator,
) paging.MapToError!*paging.PageTable {
    var created = false;

    if (entry.isUnused()) {
        if (frameAllocator.allocateFrame(.Size4KiB)) |frame| {
            entry.setAddr(frame.start_address);
            entry.setFlags(
                paging.PageTableFlags.init(
                    paging.PageTableFlags.PRESENT | paging.PageTableFlags.WRITABLE | insertFlags.value,
                ),
            );
            created = true;
        } else {
            return paging.MapToError.FrameAllocationFailed;
        }
    } else {
        const raw_insert_flags = insertFlags.value;
        const raw_entry_flags = entry.getFlags().value;
        const combined_raw_flags = raw_insert_flags | raw_entry_flags;

        if (raw_insert_flags != 0 and combined_raw_flags != raw_insert_flags) {
            entry.setFlags(.{ .value = combined_raw_flags });
        }
    }

    const page_table = nextTablePage.start_address.toPtr(*paging.PageTable);

    if (created) page_table.zero();

    return page_table;
}

fn p3Ptr(
    comptime size: paging.PageSize,
    page: paging.CreatePage(size),
    recursive_index: paging.PageTableIndex,
) *paging.PageTable {
    return p3Page(size, page, recursive_index).start_address.toPtr(*paging.PageTable);
}

fn p3Page(
    comptime size: paging.PageSize,
    page: paging.CreatePage(size),
    recursive_index: paging.PageTableIndex,
) paging.Page {
    return paging.pageFromTableIndices(
        recursive_index,
        recursive_index,
        recursive_index,
        page.p4Index(),
    );
}

fn p2Ptr(
    comptime size: paging.PageSize,
    page: paging.CreatePage(size),
    recursive_index: paging.PageTableIndex,
) *paging.PageTable {
    return p2Page(size, page, recursive_index).start_address.toPtr(*paging.PageTable);
}

fn p2Page(
    comptime size: paging.PageSize,
    page: paging.CreatePage(size),
    recursive_index: paging.PageTableIndex,
) paging.Page {
    return paging.pageFromTableIndices(
        recursive_index,
        recursive_index,
        page.p4Index(),
        page.p3Index(),
    );
}

fn p1Ptr(
    comptime size: paging.PageSize,
    page: paging.CreatePage(size),
    recursive_index: paging.PageTableIndex,
) *paging.PageTable {
    return p1Page(size, page, recursive_index).start_address.toPtr(*paging.PageTable);
}

fn p1Page(
    comptime size: paging.PageSize,
    page: paging.CreatePage(size),
    recursive_index: paging.PageTableIndex,
) paging.Page {
    return paging.pageFromTableIndices(
        recursive_index,
        page.p4Index(),
        page.p3Index(),
        page.p2Index(),
    );
}

test "" {
    std.testing.refAllDecls(@This());
}
