usingnamespace @import("../../../common.zig");

const paging = x86_64.structures.paging;
const mapping = paging.mapping;
const Mapper = mapping.Mapper;

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
        const page = paging.Page.containingAddress(x86_64.VirtAddr.initPanic(@ptrToInt(table)));
        const recursive_index = page.p4Index();
        const recursive_index_value = recursive_index.value;

        if (page.p3Index().value != recursive_index_value or
            page.p2Index().value != recursive_index_value or
            page.p1Index().value != recursive_index_value)
        {
            return InvalidPageTable.NotRecursive;
        }

        const recursive_index_frame = table.getAtIndex(recursive_index).getFrame() catch return InvalidPageTable.NotRecursive;
        if (x86_64.registers.control.Cr3.read().phys_frame.start_address.value != recursive_index_frame.start_address.value) {
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
    ) mapping.MapToError!mapping.MapperFlush1GiB {
        var self = getSelfPtr(mapper);

        const parent_flags = parent_table_flags.sanitizeForParent();

        const p3 = try createNextTable(
            self.level_4_table.getAtIndex(page.p4Index()),
            p3Page(
                .Size1GiB,
                page,
                self.recursive_index,
            ),
            parent_flags,
            frame_allocator,
        );

        var entry = p3.getAtIndex(page.p3Index());
        if (!entry.isUnused()) return mapping.MapToError.PageAlreadyMapped;

        entry.setAddr(frame.start_address);

        var new_flags = flags;
        new_flags.huge = true;
        entry.setFlags(new_flags);

        return mapping.MapperFlush1GiB.init(page);
    }

    fn unmap1GiB(
        mapper: *Mapper,
        page: paging.Page1GiB,
    ) mapping.UnmapError!mapping.UnmapResult1GiB {
        var self = getSelfPtr(mapper);

        _ = self.level_4_table.getAtIndex(page.p4Index()).getFrame() catch |err| switch (err) {
            paging.FrameError.FrameNotPresent => return mapping.UnmapError.PageNotMapped,
            paging.FrameError.HugeFrame => return mapping.UnmapError.ParentEntryHugePage,
        };

        const p3 = p3Ptr(.Size1GiB, page, self.recursive_index);

        const p3_entry = p3.getAtIndex(page.p3Index());
        const flags = p3_entry.getFlags();

        if (!flags.present) return mapping.UnmapError.PageNotMapped;
        if (!flags.huge) return mapping.UnmapError.ParentEntryHugePage;

        const frame = paging.PhysFrame1GiB.fromStartAddress(p3_entry.getAddr()) catch |err| return mapping.UnmapError.InvalidFrameAddress;

        p3_entry.setUnused();

        return mapping.UnmapResult1GiB{
            .frame = frame,
            .flush = mapping.MapperFlush1GiB.init(page),
        };
    }

    fn updateFlags1GiB(
        mapper: *Mapper,
        page: paging.Page1GiB,
        flags: paging.PageTableFlags,
    ) mapping.FlagUpdateError!mapping.MapperFlush1GiB {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return mapping.FlagUpdateError.PageNotMapped;
        }

        const p3 = p3Ptr(.Size1GiB, page, self.recursive_index);

        var p3_entry = p3.getAtIndex(page.p3Index());

        if (p3_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;

        var new_flags = flags;
        new_flags.huge = true;
        p3_entry.setFlags(new_flags);

        return mapping.MapperFlush1GiB.init(page);
    }

    fn setFlagsP4Entry1GiB(
        mapper: *Mapper,
        page: paging.Page1GiB,
        flags: paging.PageTableFlags,
    ) mapping.FlagUpdateError!mapping.MapperFlushAll {
        var self = getSelfPtr(mapper);

        const p4_entry = self.level_4_table.getAtIndex(page.p4Index());
        if (p4_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;

        p4_entry.setFlags(flags);
        return mapping.MapperFlushAll{};
    }

    fn translatePage1GiB(
        mapper: *Mapper,
        page: paging.Page1GiB,
    ) mapping.TranslateError!paging.PhysFrame1GiB {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return mapping.TranslateError.NotMapped;
        }

        const p3 = p3Ptr(.Size1GiB, page, self.recursive_index);

        const p3_entry = p3.getAtIndex(page.p3Index());

        if (p3_entry.isUnused()) return mapping.TranslateError.NotMapped;

        return paging.PhysFrame1GiB.fromStartAddress(p3_entry.getAddr()) catch |err| return mapping.TranslateError.InvalidFrameAddress;
    }

    fn mapToWithTableFlags2MiB(
        mapper: *Mapper,
        page: paging.Page2MiB,
        frame: paging.PhysFrame2MiB,
        flags: paging.PageTableFlags,
        parent_table_flags: paging.PageTableFlags,
        frame_allocator: *paging.FrameAllocator,
    ) mapping.MapToError!mapping.MapperFlush2MiB {
        var self = getSelfPtr(mapper);

        const parent_flags = parent_table_flags.sanitizeForParent();

        const p3 = try createNextTable(
            self.level_4_table.getAtIndex(page.p4Index()),
            p3Page(
                .Size2MiB,
                page,
                self.recursive_index,
            ),
            parent_flags,
            frame_allocator,
        );

        const p2 = try createNextTable(
            p3.getAtIndex(page.p3Index()),
            p2Page(
                .Size2MiB,
                page,
                self.recursive_index,
            ),
            parent_flags,
            frame_allocator,
        );

        var entry = p2.getAtIndex(page.p2Index());
        if (!entry.isUnused()) return mapping.MapToError.PageAlreadyMapped;

        entry.setAddr(frame.start_address);

        var new_flags = flags;
        new_flags.huge = true;
        entry.setFlags(new_flags);

        return mapping.MapperFlush2MiB.init(page);
    }

    fn unmap2MiB(
        mapper: *Mapper,
        page: paging.Page2MiB,
    ) mapping.UnmapError!mapping.UnmapResult2MiB {
        var self = getSelfPtr(mapper);

        _ = self.level_4_table.getAtIndex(page.p4Index()).getFrame() catch |err| switch (err) {
            paging.FrameError.FrameNotPresent => return mapping.UnmapError.PageNotMapped,
            paging.FrameError.HugeFrame => return mapping.UnmapError.ParentEntryHugePage,
        };

        const p3 = p3Ptr(.Size2MiB, page, self.recursive_index);
        const p3_entry = p3.getAtIndex(page.p3Index());

        _ = p3_entry.getFrame() catch |err| switch (err) {
            paging.FrameError.FrameNotPresent => return mapping.UnmapError.PageNotMapped,
            paging.FrameError.HugeFrame => return mapping.UnmapError.ParentEntryHugePage,
        };

        const p2 = p2Ptr(.Size2MiB, page, self.recursive_index);

        const p2_entry = p2.getAtIndex(page.p2Index());
        const flags = p2_entry.getFlags();

        if (!flags.present) return mapping.UnmapError.PageNotMapped;
        if (!flags.huge) return mapping.UnmapError.ParentEntryHugePage;

        const frame = paging.PhysFrame2MiB.fromStartAddress(p2_entry.getAddr()) catch |err| return mapping.UnmapError.InvalidFrameAddress;

        p2_entry.setUnused();

        return mapping.UnmapResult2MiB{
            .frame = frame,
            .flush = mapping.MapperFlush2MiB.init(page),
        };
    }

    fn updateFlags2MiB(
        mapper: *Mapper,
        page: paging.Page2MiB,
        flags: paging.PageTableFlags,
    ) mapping.FlagUpdateError!mapping.MapperFlush2MiB {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return mapping.FlagUpdateError.PageNotMapped;
        }

        const p3 = p3Ptr(.Size2MiB, page, self.recursive_index);

        var p3_entry = p3.getAtIndex(page.p3Index());

        if (p3_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;

        const p2 = p2Ptr(.Size2MiB, page, self.recursive_index);

        var p2_entry = p2.getAtIndex(page.p2Index());

        if (p2_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;

        var new_flags = flags;
        new_flags.huge = true;
        p2_entry.setFlags(new_flags);

        return mapping.MapperFlush2MiB.init(page);
    }

    fn setFlagsP4Entry2MiB(
        mapper: *Mapper,
        page: paging.Page2MiB,
        flags: paging.PageTableFlags,
    ) mapping.FlagUpdateError!mapping.MapperFlushAll {
        var self = getSelfPtr(mapper);

        const p4_entry = self.level_4_table.getAtIndex(page.p4Index());
        if (p4_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;
        p4_entry.setFlags(flags);
        return mapping.MapperFlushAll{};
    }

    fn setFlagsP3Entry2MiB(
        mapper: *Mapper,
        page: paging.Page2MiB,
        flags: paging.PageTableFlags,
    ) mapping.FlagUpdateError!mapping.MapperFlushAll {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return mapping.FlagUpdateError.PageNotMapped;
        }

        const p3 = p3Ptr(.Size2MiB, page, self.recursive_index);

        const p3_entry = p3.getAtIndex(page.p3Index());
        if (p3_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;
        p3_entry.setFlags(flags);
        return mapping.MapperFlushAll{};
    }

    fn translatePage2MiB(
        mapper: *Mapper,
        page: paging.Page2MiB,
    ) mapping.TranslateError!paging.PhysFrame2MiB {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return mapping.TranslateError.NotMapped;
        }

        const p3 = p3Ptr(.Size2MiB, page, self.recursive_index);

        const p3_entry = p3.getAtIndex(page.p3Index());

        if (p3_entry.isUnused()) return mapping.TranslateError.NotMapped;

        const p2 = p2Ptr(.Size2MiB, page, self.recursive_index);

        const p2_entry = p2.getAtIndex(page.p2Index());

        if (p2_entry.isUnused()) return mapping.TranslateError.NotMapped;

        return paging.PhysFrame2MiB.fromStartAddress(p2_entry.getAddr()) catch |err| return mapping.TranslateError.InvalidFrameAddress;
    }

    fn mapToWithTableFlags(
        mapper: *Mapper,
        page: paging.Page,
        frame: paging.PhysFrame,
        flags: paging.PageTableFlags,
        parent_table_flags: paging.PageTableFlags,
        frame_allocator: *paging.FrameAllocator,
    ) mapping.MapToError!mapping.MapperFlush {
        var self = getSelfPtr(mapper);

        const parent_flags = parent_table_flags.sanitizeForParent();

        const p3 = try createNextTable(
            self.level_4_table.getAtIndex(page.p4Index()),
            p3Page(
                .Size4KiB,
                page,
                self.recursive_index,
            ),
            parent_flags,
            frame_allocator,
        );

        const p2 = try createNextTable(
            p3.getAtIndex(page.p3Index()),
            p2Page(
                .Size4KiB,
                page,
                self.recursive_index,
            ),
            parent_flags,
            frame_allocator,
        );

        const p1 = try createNextTable(
            p2.getAtIndex(page.p2Index()),
            p1Page(
                .Size4KiB,
                page,
                self.recursive_index,
            ),
            parent_flags,
            frame_allocator,
        );

        var entry = p1.getAtIndex(page.p1Index());
        if (!entry.isUnused()) return mapping.MapToError.PageAlreadyMapped;

        entry.setAddr(frame.start_address);
        entry.setFlags(flags);

        return mapping.MapperFlush.init(page);
    }

    fn unmap(
        mapper: *Mapper,
        page: paging.Page,
    ) mapping.UnmapError!mapping.UnmapResult {
        var self = getSelfPtr(mapper);

        _ = self.level_4_table.getAtIndex(page.p4Index()).getFrame() catch |err| switch (err) {
            paging.FrameError.FrameNotPresent => return mapping.UnmapError.PageNotMapped,
            paging.FrameError.HugeFrame => return mapping.UnmapError.ParentEntryHugePage,
        };

        const p3 = p3Ptr(.Size4KiB, page, self.recursive_index);
        const p3_entry = p3.getAtIndex(page.p3Index());

        _ = p3_entry.getFrame() catch |err| switch (err) {
            paging.FrameError.FrameNotPresent => return mapping.UnmapError.PageNotMapped,
            paging.FrameError.HugeFrame => return mapping.UnmapError.ParentEntryHugePage,
        };

        const p2 = p2Ptr(.Size4KiB, page, self.recursive_index);
        const p2_entry = p2.getAtIndex(page.p2Index());

        _ = p2_entry.getFrame() catch |err| switch (err) {
            paging.FrameError.FrameNotPresent => return mapping.UnmapError.PageNotMapped,
            paging.FrameError.HugeFrame => return mapping.UnmapError.ParentEntryHugePage,
        };

        const p1 = p2Ptr(.Size4KiB, page, self.recursive_index);
        const p1_entry = p1.getAtIndex(page.p1Index());

        const frame = p1_entry.getFrame() catch |err| switch (err) {
            paging.FrameError.FrameNotPresent => return mapping.UnmapError.PageNotMapped,
            paging.FrameError.HugeFrame => return mapping.UnmapError.ParentEntryHugePage,
        };

        p1_entry.setUnused();

        return mapping.UnmapResult{
            .frame = frame,
            .flush = mapping.MapperFlush.init(page),
        };
    }

    fn updateFlags(
        mapper: *Mapper,
        page: paging.Page,
        flags: paging.PageTableFlags,
    ) mapping.FlagUpdateError!mapping.MapperFlush {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return mapping.FlagUpdateError.PageNotMapped;
        }

        const p3 = p3Ptr(.Size4KiB, page, self.recursive_index);

        var p3_entry = p3.getAtIndex(page.p3Index());

        if (p3_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;

        const p2 = p2Ptr(.Size4KiB, page, self.recursive_index);

        var p2_entry = p2.getAtIndex(page.p2Index());

        if (p2_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;

        const p1 = p1Ptr(.Size4KiB, page, self.recursive_index);

        var p1_entry = p1.getAtIndex(page.p1Index());

        if (p1_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;

        p1_entry.setFlags(flags);

        return mapping.MapperFlush.init(page);
    }

    fn setFlagsP4Entry(
        mapper: *Mapper,
        page: paging.Page,
        flags: paging.PageTableFlags,
    ) mapping.FlagUpdateError!mapping.MapperFlushAll {
        var self = getSelfPtr(mapper);

        const p4_entry = self.level_4_table.getAtIndex(page.p4Index());
        if (p4_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;
        p4_entry.setFlags(flags);
        return mapping.MapperFlushAll{};
    }

    fn setFlagsP3Entry(
        mapper: *Mapper,
        page: paging.Page,
        flags: paging.PageTableFlags,
    ) mapping.FlagUpdateError!mapping.MapperFlushAll {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return mapping.FlagUpdateError.PageNotMapped;
        }

        const p3 = p3Ptr(.Size4KiB, page, self.recursive_index);

        const p3_entry = p3.getAtIndex(page.p3Index());
        if (p3_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;

        p3_entry.setFlags(flags);
        return mapping.MapperFlushAll{};
    }

    fn setFlagsP2Entry(
        mapper: *Mapper,
        page: paging.Page,
        flags: paging.PageTableFlags,
    ) mapping.FlagUpdateError!mapping.MapperFlushAll {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return mapping.FlagUpdateError.PageNotMapped;
        }

        const p3 = p3Ptr(.Size4KiB, page, self.recursive_index);

        const p3_entry = p3.getAtIndex(page.p3Index());
        if (p3_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;

        const p2 = p2Ptr(.Size4KiB, page, self.recursive_index);

        const p2_entry = p2.getAtIndex(page.p2Index());
        if (p2_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;

        p2_entry.setFlags(flags);
        return mapping.MapperFlushAll{};
    }

    fn translatePage(
        mapper: *Mapper,
        page: paging.Page,
    ) mapping.TranslateError!paging.PhysFrame {
        var self = getSelfPtr(mapper);

        if (self.level_4_table.getAtIndex(page.p4Index()).isUnused()) {
            return mapping.TranslateError.NotMapped;
        }

        const p3 = p3Ptr(.Size4KiB, page, self.recursive_index);

        const p3_entry = p3.getAtIndex(page.p3Index());

        if (p3_entry.isUnused()) return mapping.TranslateError.NotMapped;

        const p2 = p2Ptr(.Size4KiB, page, self.recursive_index);

        const p2_entry = p2.getAtIndex(page.p2Index());

        if (p2_entry.isUnused()) return mapping.TranslateError.NotMapped;

        const p1 = p1Ptr(.Size4KiB, page, self.recursive_index);

        const p1_entry = p1.getAtIndex(page.p1Index());

        if (p1_entry.isUnused()) return mapping.TranslateError.NotMapped;

        return paging.PhysFrame.fromStartAddress(p1_entry.getAddr()) catch |err| return mapping.TranslateError.InvalidFrameAddress;
    }

    fn translate(
        mapper: *Mapper,
        addr: x86_64.VirtAddr,
    ) mapping.TranslateError!mapping.TranslateResult {
        var self = getSelfPtr(mapper);
        const page = paging.Page.containingAddress(addr);

        const p4_entry = self.level_4_table.getAtIndex(addr.p4Index());
        if (p4_entry.isUnused()) {
            return mapping.TranslateError.NotMapped;
        }

        if (p4_entry.getFlags().huge) {
            @panic("level 4 entry has huge page bit set");
        }

        const p3 = p3Ptr(.Size4KiB, page, self.recursive_index);

        const p3_entry = p3.getAtIndex(page.p3Index());
        if (p3_entry.isUnused()) return mapping.TranslateError.NotMapped;

        const p3_flags = p3_entry.getFlags();
        if (p3_flags.huge) {
            return mapping.TranslateResult{
                .Frame1GiB = .{
                    .frame = paging.PhysFrame1GiB.containingAddress(p3_entry.getAddr()),
                    .offset = addr.value & 0o777_777_7777,
                    .flags = p3_flags,
                },
            };
        }

        const p2 = p2Ptr(.Size4KiB, page, self.recursive_index);

        const p2_entry = p2.getAtIndex(addr.p2Index());
        if (p2_entry.isUnused()) return mapping.TranslateError.NotMapped;

        const p2_flags = p2_entry.getFlags();
        if (p2_flags.huge) {
            return mapping.TranslateResult{
                .Frame2MiB = .{
                    .frame = paging.PhysFrame2MiB.containingAddress(p2_entry.getAddr()),
                    .offset = addr.value & 0o777_7777,
                    .flags = p2_flags,
                },
            };
        }

        const p1 = p2Ptr(.Size4KiB, page, self.recursive_index);

        const p1_entry = p1.getAtIndex(addr.p1Index());
        if (p1_entry.isUnused()) return mapping.TranslateError.NotMapped;

        const p1_flags = p1_entry.getFlags();
        if (p1_flags.huge) {
            @panic("level 1 entry has huge page bit set");
        }

        const frame = paging.PhysFrame.fromStartAddress(p1_entry.getAddr()) catch |err| return mapping.TranslateError.InvalidFrameAddress;

        return mapping.TranslateResult{
            .Frame4KiB = .{
                .frame = frame,
                .offset = @as(u64, addr.pageOffset().value),
                .flags = p1_flags,
            },
        };
    }

    fn makeMapper() Mapper {
        return .{
            .z_impl_mapToWithTableFlags1GiB = mapToWithTableFlags1GiB,
            .z_impl_unmap1GiB = unmap1GiB,
            .z_impl_updateFlags1GiB = updateFlags1GiB,
            .z_impl_setFlagsP4Entry1GiB = setFlagsP4Entry1GiB,
            .z_impl_translatePage1GiB = translatePage1GiB,
            .z_impl_mapToWithTableFlags2MiB = mapToWithTableFlags2MiB,
            .z_impl_unmap2MiB = unmap2MiB,
            .z_impl_updateFlags2MiB = updateFlags2MiB,
            .z_impl_setFlagsP4Entry2MiB = setFlagsP4Entry2MiB,
            .z_impl_setFlagsP3Entry2MiB = setFlagsP3Entry2MiB,
            .z_impl_translatePage2MiB = translatePage2MiB,
            .z_impl_mapToWithTableFlags = mapToWithTableFlags,
            .z_impl_unmap = unmap,
            .z_impl_updateFlags = updateFlags,
            .z_impl_setFlagsP4Entry = setFlagsP4Entry,
            .z_impl_setFlagsP3Entry = setFlagsP3Entry,
            .z_impl_setFlagsP2Entry = setFlagsP2Entry,
            .z_impl_translatePage = translatePage,
            .z_impl_translate = translate,
        };
    }

    comptime {
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
) mapping.MapToError!*paging.PageTable {
    var created = false;

    if (entry.isUnused()) {
        if (frameAllocator.allocate4KiB()) |frame| {
            entry.setAddr(frame.start_address);

            var flags = insertFlags;
            flags.present = true;
            flags.writeable = true;
            entry.setFlags(flags);

            created = true;
        } else {
            return mapping.MapToError.FrameAllocationFailed;
        }
    } else {
        const raw_insert_flags = insertFlags.toU64();
        const raw_entry_flags = entry.getFlags().toU64();
        const combined_raw_flags = raw_insert_flags | raw_entry_flags;

        if (raw_insert_flags != 0 and combined_raw_flags != raw_insert_flags) {
            entry.setFlags(paging.PageTableFlags.fromU64(combined_raw_flags));
        }
    }

    const page_table = nextTablePage.start_address.toPtr(*paging.PageTable);

    if (created) page_table.zero();

    return page_table;
}

fn getPageFromSize(comptime page_size: paging.PageSize) type {
    return switch (page_size) {
        .Size4KiB => paging.Page,
        .Size2MiB => paging.Page2MiB,
        .Size1GiB => paging.Page1GiB,
    };
}

fn p3Ptr(
    comptime size: paging.PageSize,
    page: getPageFromSize(size),
    recursive_index: paging.PageTableIndex,
) *paging.PageTable {
    return p3Page(size, page, recursive_index).start_address.toPtr(*paging.PageTable);
}

fn p3Page(
    comptime size: paging.PageSize,
    page: getPageFromSize(size),
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
    page: getPageFromSize(size),
    recursive_index: paging.PageTableIndex,
) *paging.PageTable {
    return p2Page(size, page, recursive_index).start_address.toPtr(*paging.PageTable);
}

fn p2Page(
    comptime size: paging.PageSize,
    page: getPageFromSize(size),
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
    page: getPageFromSize(size),
    recursive_index: paging.PageTableIndex,
) *paging.PageTable {
    return p1Page(size, page, recursive_index).start_address.toPtr(*paging.PageTable);
}

fn p1Page(
    comptime size: paging.PageSize,
    page: getPageFromSize(size),
    recursive_index: paging.PageTableIndex,
) paging.Page {
    return paging.pageFromTableIndices(
        recursive_index,
        page.p4Index(),
        page.p3Index(),
        page.p2Index(),
    );
}

comptime {
    std.testing.refAllDecls(@This());
}
