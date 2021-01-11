usingnamespace @import("../../../common.zig");

const Mapper = paging.Mapper;
const paging = structures.paging;

/// A Mapper implementation that relies on a PhysAddr to VirtAddr conversion function.
pub fn MappedPageTable(
    comptime context_type: type,
    comptime frame_to_pointer: fn (context_type, phys_frame: paging.PhysFrame) *paging.PageTable,
) type {
    return struct {
        const Self = @This();
        const page_table_walker = PageTableWalker(context_type, frame_to_pointer);

        mapper: Mapper,
        level_4_table: *paging.PageTable,
        context: context_type,

        pub fn init(context: context_type, level_4_table: *paging.PageTable) Self {
            return .{
                .mapper = makeMapper(),
                .context = context,
                .level_4_table = level_4_table,
            };
        }

        inline fn getSelfPtr(mapper: *Mapper) *Self {
            return @fieldParentPtr(Self, "mapper", mapper);
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

            const p3 = page_table_walker.createNextTable(
                self.context,
                self.level_4_table.getAtIndex(page.p4Index()),
                parent_table_flags,
                frame_allocator,
            ) catch |err| switch (err) {
                PageTableCreateError.MappedToHugePage => return paging.MapToError.ParentEntryHugePage,
                PageTableCreateError.FrameAllocationFailed => return paging.MapToError.FrameAllocationFailed,
            };

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

            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.UnmapError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return paging.UnmapError.PageNotMapped,
            };

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

            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return paging.FlagUpdateError.PageNotMapped,
            };

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

            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.TranslateError.InvalidFrameAddress,
                PageTableWalkError.NotMapped => return paging.TranslateError.NotMapped,
            };

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

            const p3 = page_table_walker.createNextTable(
                self.context,
                self.level_4_table.getAtIndex(page.p4Index()),
                parent_table_flags,
                frame_allocator,
            ) catch |err| switch (err) {
                PageTableCreateError.MappedToHugePage => return paging.MapToError.ParentEntryHugePage,
                PageTableCreateError.FrameAllocationFailed => return paging.MapToError.FrameAllocationFailed,
            };
            const p2 = page_table_walker.createNextTable(
                self.context,
                p3.getAtIndex(page.p3Index()),
                parent_table_flags,
                frame_allocator,
            ) catch |err| switch (err) {
                PageTableCreateError.MappedToHugePage => return paging.MapToError.ParentEntryHugePage,
                PageTableCreateError.FrameAllocationFailed => return paging.MapToError.FrameAllocationFailed,
            };

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

            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.UnmapError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return paging.UnmapError.PageNotMapped,
            };
            const p2 = page_table_walker.nextTable(self.context, p3.getAtIndex(page.p3Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.UnmapError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return paging.UnmapError.PageNotMapped,
            };

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

            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return paging.FlagUpdateError.PageNotMapped,
            };
            const p2 = page_table_walker.nextTable(self.context, p3.getAtIndex(page.p3Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return paging.FlagUpdateError.PageNotMapped,
            };

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

            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return paging.FlagUpdateError.PageNotMapped,
            };

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

            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.TranslateError.InvalidFrameAddress,
                PageTableWalkError.NotMapped => return paging.TranslateError.NotMapped,
            };
            const p2 = page_table_walker.nextTable(self.context, p3.getAtIndex(page.p3Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.TranslateError.InvalidFrameAddress,
                PageTableWalkError.NotMapped => return paging.TranslateError.NotMapped,
            };

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

            const p3 = page_table_walker.createNextTable(
                self.context,
                self.level_4_table.getAtIndex(page.p4Index()),
                parent_table_flags,
                frame_allocator,
            ) catch |err| switch (err) {
                PageTableCreateError.MappedToHugePage => return paging.MapToError.ParentEntryHugePage,
                PageTableCreateError.FrameAllocationFailed => return paging.MapToError.FrameAllocationFailed,
            };
            const p2 = page_table_walker.createNextTable(
                self.context,
                p3.getAtIndex(page.p3Index()),
                parent_table_flags,
                frame_allocator,
            ) catch |err| switch (err) {
                PageTableCreateError.MappedToHugePage => return paging.MapToError.ParentEntryHugePage,
                PageTableCreateError.FrameAllocationFailed => return paging.MapToError.FrameAllocationFailed,
            };
            const p1 = page_table_walker.createNextTable(
                self.context,
                p2.getAtIndex(page.p2Index()),
                parent_table_flags,
                frame_allocator,
            ) catch |err| switch (err) {
                PageTableCreateError.MappedToHugePage => return paging.MapToError.ParentEntryHugePage,
                PageTableCreateError.FrameAllocationFailed => return paging.MapToError.FrameAllocationFailed,
            };

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

            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.UnmapError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return paging.UnmapError.PageNotMapped,
            };
            const p2 = page_table_walker.nextTable(self.context, p3.getAtIndex(page.p3Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.UnmapError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return paging.UnmapError.PageNotMapped,
            };
            const p1 = page_table_walker.nextTable(self.context, p2.getAtIndex(page.p2Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.UnmapError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return paging.UnmapError.PageNotMapped,
            };

            const p1_entry = p1.getAtIndex(page.p1Index());
            const flags = p1_entry.getFlags();

            if (flags.value & paging.PageTableFlags.PRESENT == 0) return paging.UnmapError.PageNotMapped;
            if (flags.value & paging.PageTableFlags.HUGE_PAGE == 0) return paging.UnmapError.ParentEntryHugePage;

            const frame = paging.PhysFrame.fromStartAddress(p1_entry.getAddr()) catch |err| return paging.UnmapError.InvalidFrameAddress;

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

            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return paging.FlagUpdateError.PageNotMapped,
            };
            const p2 = page_table_walker.nextTable(self.context, p3.getAtIndex(page.p3Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return paging.FlagUpdateError.PageNotMapped,
            };
            const p1 = page_table_walker.nextTable(self.context, p2.getAtIndex(page.p2Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return paging.FlagUpdateError.PageNotMapped,
            };

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

            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return paging.FlagUpdateError.PageNotMapped,
            };

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

            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return paging.FlagUpdateError.PageNotMapped,
            };
            const p2 = page_table_walker.nextTable(self.context, p3.getAtIndex(page.p3Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return paging.FlagUpdateError.PageNotMapped,
            };

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

            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.TranslateError.InvalidFrameAddress,
                PageTableWalkError.NotMapped => return paging.TranslateError.NotMapped,
            };
            const p2 = page_table_walker.nextTable(self.context, p3.getAtIndex(page.p3Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.TranslateError.InvalidFrameAddress,
                PageTableWalkError.NotMapped => return paging.TranslateError.NotMapped,
            };
            const p1 = page_table_walker.nextTable(self.context, p2.getAtIndex(page.p2Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return paging.TranslateError.InvalidFrameAddress,
                PageTableWalkError.NotMapped => return paging.TranslateError.NotMapped,
            };

            const p1_entry = p1.getAtIndex(page.p1Index());

            if (p1_entry.isUnused()) return paging.TranslateError.NotMapped;

            return paging.PhysFrame.fromStartAddress(p1_entry.getAddr()) catch |err| return paging.TranslateError.InvalidFrameAddress;
        }

        fn translate(
            mapper: *Mapper,
            addr: VirtAddr,
        ) paging.TranslateError!paging.TranslateResult {
            var self = getSelfPtr(mapper);

            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(addr.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => @panic("level 4 entry has huge page bit set"),
                PageTableWalkError.NotMapped => return paging.TranslateError.NotMapped,
            };

            const p2 = page_table_walker.nextTable(self.context, p3.getAtIndex(addr.p3Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => {
                    const entry = p3.getAtIndex(addr.p3Index());
                    const frame = paging.PhysFrame1GiB.containingAddress(entry.getAddr());
                    const offset = addr.value & 0o777_777_7777;
                    return paging.TranslateResult{
                        .Frame1GiB = .{
                            .frame = frame,
                            .offset = offset,
                            .flags = entry.getFlags(),
                        },
                    };
                },
                PageTableWalkError.NotMapped => return paging.TranslateError.NotMapped,
            };

            const p1 = page_table_walker.nextTable(self.context, p2.getAtIndex(addr.p2Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => {
                    const entry = p2.getAtIndex(addr.p2Index());
                    const frame = paging.PhysFrame2MiB.containingAddress(entry.getAddr());
                    const offset = addr.value & 0o777_7777;
                    return paging.TranslateResult{
                        .Frame2MiB = .{
                            .frame = frame,
                            .offset = offset,
                            .flags = entry.getFlags(),
                        },
                    };
                },
                PageTableWalkError.NotMapped => {
                    return paging.TranslateError.NotMapped;
                },
            };

            const p1_entry = p1.getAtIndex(addr.p1Index());

            if (p1_entry.isUnused()) return paging.TranslateError.NotMapped;

            const frame = paging.PhysFrame.fromStartAddress(p1_entry.getAddr()) catch |err| return paging.TranslateError.InvalidFrameAddress;

            return paging.TranslateResult{
                .Frame4KiB = .{
                    .frame = frame,
                    .offset = @as(u64, addr.pageOffset().value),
                    .flags = p1_entry.getFlags(),
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
}

fn PageTableWalker(
    comptime context_type: type,
    comptime frame_to_pointer: fn (context_type, phys_frame: paging.PhysFrame) *paging.PageTable,
) type {
    return struct {
        const Self = @This();

        /// Internal helper function to get a reference to the page table of the next level.
        pub fn nextTable(context: context_type, entry: *paging.PageTableEntry) PageTableWalkError!*paging.PageTable {
            return frame_to_pointer(context, entry.getFrame() catch |err| switch (err) {
                error.HugeFrame => return PageTableWalkError.MappedToHugePage,
                error.FrameNotPresent => return PageTableWalkError.NotMapped,
            });
        }

        /// Internal helper function to create the page table of the next level if needed.
        pub fn createNextTable(
            context: context_type,
            entry: *paging.PageTableEntry,
            insert_flags: paging.PageTableFlags,
            frame_allocator: *paging.FrameAllocator,
        ) PageTableCreateError!*paging.PageTable {
            var created = false;

            if (entry.isUnused()) {
                if (frame_allocator.allocateFrame(.Size4KiB)) |frame| {
                    entry.setAddr(frame.start_address);
                    entry.setFlags(insert_flags);
                    created = true;
                } else {
                    return PageTableCreateError.FrameAllocationFailed;
                }
            } else {
                const raw_insert_flags = insert_flags.value;
                const raw_entry_flags = entry.getFlags().value;
                const combined_raw_flags = raw_insert_flags | raw_entry_flags;

                if (raw_insert_flags != 0 and combined_raw_flags != raw_insert_flags) {
                    entry.setFlags(.{ .value = combined_raw_flags });
                }
            }

            const page_table = nextTable(context, entry) catch |err| switch (err) {
                error.MappedToHugePage => return PageTableCreateError.MappedToHugePage,
                error.NotMapped => @panic("entry should be mapped at this point"),
            };

            if (created) page_table.zero();

            return page_table;
        }

        test "" {
            std.testing.refAllDecls(@This());
        }
    };
}

const PageTableWalkError = error{
    NotMapped,
    MappedToHugePage,
};

const PageTableCreateError = error{
    MappedToHugePage,
    FrameAllocationFailed,
};

test "" {
    std.testing.refAllDecls(@This());
}
