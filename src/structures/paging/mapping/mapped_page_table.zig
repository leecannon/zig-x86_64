usingnamespace @import("../../../common.zig");

const paging = x86_64.structures.paging;
const mapping = paging.mapping;
const Mapper = mapping.Mapper;

const physToVirt = struct {
    pub fn physToVirt(offset: x86_64.VirtAddr, phys_frame: paging.PhysFrame) *paging.PageTable {
        return x86_64.VirtAddr.initPanic(offset.value + phys_frame.start_address.value).toPtr(*paging.PageTable);
    }
}.physToVirt;

pub const OffsetPageTable = MappedPageTable(x86_64.VirtAddr, physToVirt);

/// A Mapper implementation that relies on a x86_64.PhysAddr to x86_64.VirtAddr conversion function.
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

        pub fn mapTo1GiB(
            self: *Self,
            page: paging.Page1GiB,
            frame: paging.PhysFrame1GiB,
            flags: paging.PageTableFlags,
            frame_allocator: *paging.FrameAllocator,
        ) mapping.MapToError!mapping.MapperFlush1GiB {
            return self.mapToWithTableFlags1GiB(page, frame, flags, flags, frame_allocator);
        }

        pub fn mapToWithTableFlags1GiB(
            self: *Self,
            page: paging.Page1GiB,
            frame: paging.PhysFrame1GiB,
            flags: paging.PageTableFlags,
            parent_table_flags: paging.PageTableFlags,
            frame_allocator: *paging.FrameAllocator,
        ) mapping.MapToError!mapping.MapperFlush1GiB {
            const parent_flags = parent_table_flags.sanitizeForParent();

            const p3 = page_table_walker.createNextTable(
                self.context,
                self.level_4_table.getAtIndex(page.p4Index()),
                parent_flags,
                frame_allocator,
            ) catch |err| switch (err) {
                PageTableCreateError.MappedToHugePage => return mapping.MapToError.ParentEntryHugePage,
                PageTableCreateError.FrameAllocationFailed => return mapping.MapToError.FrameAllocationFailed,
            };

            var entry = p3.getAtIndex(page.p3Index());
            if (!entry.isUnused()) return mapping.MapToError.PageAlreadyMapped;

            entry.setAddr(frame.start_address);

            var new_flags = flags;
            new_flags.huge = true;
            entry.setFlags(new_flags);

            return mapping.MapperFlush1GiB.init(page);
        }

        fn impl_mapToWithTableFlags1GiB(
            mapper: *Mapper,
            page: paging.Page1GiB,
            frame: paging.PhysFrame1GiB,
            flags: paging.PageTableFlags,
            parent_table_flags: paging.PageTableFlags,
            frame_allocator: *paging.FrameAllocator,
        ) mapping.MapToError!mapping.MapperFlush1GiB {
            return getSelfPtr(mapper).mapToWithTableFlags1GiB(page, frame, flags, parent_table_flags, frame_allocator);
        }

        pub fn unmap1GiB(self: *Self, page: paging.Page1GiB) mapping.UnmapError!mapping.UnmapResult1GiB {
            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.UnmapError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return mapping.UnmapError.PageNotMapped,
            };

            const p3_entry = p3.getAtIndex(page.p3Index());
            const flags = p3_entry.getFlags();

            if (!flags.present) return mapping.UnmapError.PageNotMapped;
            if (flags.huge) return mapping.UnmapError.ParentEntryHugePage;

            const frame = paging.PhysFrame1GiB.fromStartAddress(p3_entry.getAddr()) catch |err| return mapping.UnmapError.InvalidFrameAddress;

            p3_entry.setUnused();

            return mapping.UnmapResult1GiB{
                .frame = frame,
                .flush = mapping.MapperFlush1GiB.init(page),
            };
        }

        fn impl_unmap1GiB(mapper: *Mapper, page: paging.Page1GiB) mapping.UnmapError!mapping.UnmapResult1GiB {
            return getSelfPtr(mapper).unmap1GiB(page);
        }

        pub fn updateFlags1GiB(
            self: *Self,
            page: paging.Page1GiB,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlush1GiB {
            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return mapping.FlagUpdateError.PageNotMapped,
            };

            var p3_entry = p3.getAtIndex(page.p3Index());

            if (p3_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;

            var new_flags = flags;
            new_flags.huge = true;
            p3_entry.setFlags(new_flags);

            return mapping.MapperFlush1GiB.init(page);
        }

        fn impl_updateFlags1GiB(
            mapper: *Mapper,
            page: paging.Page1GiB,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlush1GiB {
            return getSelfPtr(mapper).updateFlags1GiB(page, flags);
        }

        pub fn setFlagsP4Entry1GiB(
            self: *Self,
            page: paging.Page1GiB,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlushAll {
            const p4_entry = self.level_4_table.getAtIndex(page.p4Index());
            if (p4_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;
            p4_entry.setFlags(flags);
            return mapping.MapperFlushAll{};
        }

        fn impl_setFlagsP4Entry1GiB(
            mapper: *Mapper,
            page: paging.Page1GiB,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlushAll {
            return getSelfPtr(mapper).setFlagsP4Entry1GiB(page, flags);
        }

        pub fn translatePage1GiB(self: *const Self, page: paging.Page1GiB) mapping.TranslateError!paging.PhysFrame1GiB {
            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.TranslateError.InvalidFrameAddress,
                PageTableWalkError.NotMapped => return mapping.TranslateError.NotMapped,
            };

            const p3_entry = p3.getAtIndex(page.p3Index());

            if (p3_entry.isUnused()) return mapping.TranslateError.NotMapped;

            return paging.PhysFrame1GiB.fromStartAddress(p3_entry.getAddr()) catch |err| return mapping.TranslateError.InvalidFrameAddress;
        }

        fn impl_translatePage1GiB(mapper: *Mapper, page: paging.Page1GiB) mapping.TranslateError!paging.PhysFrame1GiB {
            return getSelfPtr(mapper).translatePage1GiB(page);
        }

        pub fn mapTo2MiB(
            self: *Self,
            page: paging.Page2MiB,
            frame: paging.PhysFrame2MiB,
            flags: paging.PageTableFlags,
            frame_allocator: *paging.FrameAllocator,
        ) mapping.MapToError!mapping.MapperFlush2MiB {
            return self.mapToWithTableFlags2MiB(page, frame, flags, flags, frame_allocator);
        }

        pub fn mapToWithTableFlags2MiB(
            self: *Self,
            page: paging.Page2MiB,
            frame: paging.PhysFrame2MiB,
            flags: paging.PageTableFlags,
            parent_table_flags: paging.PageTableFlags,
            frame_allocator: *paging.FrameAllocator,
        ) mapping.MapToError!mapping.MapperFlush2MiB {
            const parent_flags = parent_table_flags.sanitizeForParent();

            const p3 = page_table_walker.createNextTable(
                self.context,
                self.level_4_table.getAtIndex(page.p4Index()),
                parent_flags,
                frame_allocator,
            ) catch |err| switch (err) {
                PageTableCreateError.MappedToHugePage => return mapping.MapToError.ParentEntryHugePage,
                PageTableCreateError.FrameAllocationFailed => return mapping.MapToError.FrameAllocationFailed,
            };
            const p2 = page_table_walker.createNextTable(
                self.context,
                p3.getAtIndex(page.p3Index()),
                parent_flags,
                frame_allocator,
            ) catch |err| switch (err) {
                PageTableCreateError.MappedToHugePage => return mapping.MapToError.ParentEntryHugePage,
                PageTableCreateError.FrameAllocationFailed => return mapping.MapToError.FrameAllocationFailed,
            };

            var entry = p2.getAtIndex(page.p2Index());
            if (!entry.isUnused()) return mapping.MapToError.PageAlreadyMapped;

            entry.setAddr(frame.start_address);

            var new_flags = flags;
            new_flags.huge = true;
            entry.setFlags(new_flags);

            return mapping.MapperFlush2MiB.init(page);
        }

        fn impl_mapToWithTableFlags2MiB(
            mapper: *Mapper,
            page: paging.Page2MiB,
            frame: paging.PhysFrame2MiB,
            flags: paging.PageTableFlags,
            parent_table_flags: paging.PageTableFlags,
            frame_allocator: *paging.FrameAllocator,
        ) mapping.MapToError!mapping.MapperFlush2MiB {
            return getSelfPtr(mapper).mapToWithTableFlags2MiB(page, frame, flags, parent_table_flags, frame_allocator);
        }

        pub fn unmap2MiB(self: *Self, page: paging.Page2MiB) mapping.UnmapError!mapping.UnmapResult2MiB {
            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.UnmapError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return mapping.UnmapError.PageNotMapped,
            };
            const p2 = page_table_walker.nextTable(self.context, p3.getAtIndex(page.p3Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.UnmapError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return mapping.UnmapError.PageNotMapped,
            };

            const p2_entry = p2.getAtIndex(page.p2Index());
            const flags = p2_entry.getFlags();

            if (!flags.present) return mapping.UnmapError.PageNotMapped;
            if (flags.huge) return mapping.UnmapError.ParentEntryHugePage;

            const frame = paging.PhysFrame2MiB.fromStartAddress(p2_entry.getAddr()) catch |err| return mapping.UnmapError.InvalidFrameAddress;

            p2_entry.setUnused();

            return mapping.UnmapResult2MiB{
                .frame = frame,
                .flush = mapping.MapperFlush2MiB.init(page),
            };
        }

        fn impl_unmap2MiB(mapper: *Mapper, page: paging.Page2MiB) mapping.UnmapError!mapping.UnmapResult2MiB {
            return getSelfPtr(mapper).unmap2MiB(page);
        }

        pub fn updateFlags2MiB(
            self: *Self,
            page: paging.Page2MiB,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlush2MiB {
            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return mapping.FlagUpdateError.PageNotMapped,
            };
            const p2 = page_table_walker.nextTable(self.context, p3.getAtIndex(page.p3Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return mapping.FlagUpdateError.PageNotMapped,
            };

            var p2_entry = p2.getAtIndex(page.p2Index());

            if (p2_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;

            var new_flags = flags;
            new_flags.huge = true;
            p2_entry.setFlags(new_flags);

            return mapping.MapperFlush2MiB.init(page);
        }

        fn impl_updateFlags2MiB(
            mapper: *Mapper,
            page: paging.Page2MiB,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlush2MiB {
            return getSelfPtr(mapper).updateFlags2MiB(page, flags);
        }

        pub fn setFlagsP4Entry2MiB(
            self: *Self,
            page: paging.Page2MiB,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlushAll {
            const p4_entry = self.level_4_table.getAtIndex(page.p4Index());
            if (p4_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;
            p4_entry.setFlags(flags);
            return mapping.MapperFlushAll{};
        }

        fn impl_setFlagsP4Entry2MiB(
            mapper: *Mapper,
            page: paging.Page2MiB,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlushAll {
            return getSelfPtr(mapper).setFlagsP4Entry2MiB(page, flags);
        }

        pub fn setFlagsP3Entry2MiB(
            self: *Self,
            page: paging.Page2MiB,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlushAll {
            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return mapping.FlagUpdateError.PageNotMapped,
            };

            const p3_entry = p3.getAtIndex(page.p3Index());
            if (p3_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;
            p3_entry.setFlags(flags);
            return mapping.MapperFlushAll{};
        }

        fn impl_setFlagsP3Entry2MiB(
            mapper: *Mapper,
            page: paging.Page2MiB,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlushAll {
            return getSelfPtr(mapper).setFlagsP3Entry2MiB(page, flags);
        }

        pub fn translatePage2MiB(self: *const Self, page: paging.Page2MiB) mapping.TranslateError!paging.PhysFrame2MiB {
            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.TranslateError.InvalidFrameAddress,
                PageTableWalkError.NotMapped => return mapping.TranslateError.NotMapped,
            };
            const p2 = page_table_walker.nextTable(self.context, p3.getAtIndex(page.p3Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.TranslateError.InvalidFrameAddress,
                PageTableWalkError.NotMapped => return mapping.TranslateError.NotMapped,
            };

            const p2_entry = p2.getAtIndex(page.p2Index());

            if (p2_entry.isUnused()) return mapping.TranslateError.NotMapped;

            return paging.PhysFrame2MiB.fromStartAddress(p2_entry.getAddr()) catch |err| return mapping.TranslateError.InvalidFrameAddress;
        }

        fn impl_translatePage2MiB(mapper: *Mapper, page: paging.Page2MiB) mapping.TranslateError!paging.PhysFrame2MiB {
            return getSelfPtr(mapper).translatePage2MiB(page);
        }

        pub fn mapTo(
            self: *Self,
            page: paging.Page,
            frame: paging.PhysFrame,
            flags: paging.PageTableFlags,
            frame_allocator: *paging.FrameAllocator,
        ) mapping.MapToError!mapping.MapperFlush {
            return self.mapToWithTableFlags(page, frame, flags, flags, frame_allocator);
        }

        pub fn mapToWithTableFlags(
            self: *Self,
            page: paging.Page,
            frame: paging.PhysFrame,
            flags: paging.PageTableFlags,
            parent_table_flags: paging.PageTableFlags,
            frame_allocator: *paging.FrameAllocator,
        ) mapping.MapToError!mapping.MapperFlush {
            const parent_flags = parent_table_flags.sanitizeForParent();

            const p3 = page_table_walker.createNextTable(
                self.context,
                self.level_4_table.getAtIndex(page.p4Index()),
                parent_flags,
                frame_allocator,
            ) catch |err| switch (err) {
                PageTableCreateError.MappedToHugePage => return mapping.MapToError.ParentEntryHugePage,
                PageTableCreateError.FrameAllocationFailed => return mapping.MapToError.FrameAllocationFailed,
            };
            const p2 = page_table_walker.createNextTable(
                self.context,
                p3.getAtIndex(page.p3Index()),
                parent_flags,
                frame_allocator,
            ) catch |err| switch (err) {
                PageTableCreateError.MappedToHugePage => return mapping.MapToError.ParentEntryHugePage,
                PageTableCreateError.FrameAllocationFailed => return mapping.MapToError.FrameAllocationFailed,
            };
            const p1 = page_table_walker.createNextTable(
                self.context,
                p2.getAtIndex(page.p2Index()),
                parent_flags,
                frame_allocator,
            ) catch |err| switch (err) {
                PageTableCreateError.MappedToHugePage => return mapping.MapToError.ParentEntryHugePage,
                PageTableCreateError.FrameAllocationFailed => return mapping.MapToError.FrameAllocationFailed,
            };

            var entry = p1.getAtIndex(page.p1Index());
            if (!entry.isUnused()) return mapping.MapToError.PageAlreadyMapped;

            entry.setAddr(frame.start_address);
            entry.setFlags(flags);

            return mapping.MapperFlush.init(page);
        }

        fn impl_mapToWithTableFlags(
            mapper: *Mapper,
            page: paging.Page,
            frame: paging.PhysFrame,
            flags: paging.PageTableFlags,
            parent_table_flags: paging.PageTableFlags,
            frame_allocator: *paging.FrameAllocator,
        ) mapping.MapToError!mapping.MapperFlush {
            return getSelfPtr(mapper).mapToWithTableFlags(page, frame, flags, parent_table_flags, frame_allocator);
        }

        pub fn unmap(self: *Self, page: paging.Page) mapping.UnmapError!mapping.UnmapResult {
            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.UnmapError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return mapping.UnmapError.PageNotMapped,
            };
            const p2 = page_table_walker.nextTable(self.context, p3.getAtIndex(page.p3Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.UnmapError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return mapping.UnmapError.PageNotMapped,
            };
            const p1 = page_table_walker.nextTable(self.context, p2.getAtIndex(page.p2Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.UnmapError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return mapping.UnmapError.PageNotMapped,
            };

            const p1_entry = p1.getAtIndex(page.p1Index());
            const flags = p1_entry.getFlags();

            if (!flags.present) return mapping.UnmapError.PageNotMapped;
            if (flags.huge) return mapping.UnmapError.ParentEntryHugePage;

            const frame = paging.PhysFrame.fromStartAddress(p1_entry.getAddr()) catch |err| return mapping.UnmapError.InvalidFrameAddress;

            p1_entry.setUnused();

            return mapping.UnmapResult{
                .frame = frame,
                .flush = mapping.MapperFlush.init(page),
            };
        }

        fn impl_unmap(mapper: *Mapper, page: paging.Page) mapping.UnmapError!mapping.UnmapResult {
            return getSelfPtr(mapper).unmap(page);
        }

        pub fn updateFlags(
            self: *Self,
            page: paging.Page,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlush {
            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return mapping.FlagUpdateError.PageNotMapped,
            };
            const p2 = page_table_walker.nextTable(self.context, p3.getAtIndex(page.p3Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return mapping.FlagUpdateError.PageNotMapped,
            };
            const p1 = page_table_walker.nextTable(self.context, p2.getAtIndex(page.p2Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return mapping.FlagUpdateError.PageNotMapped,
            };

            var p1_entry = p1.getAtIndex(page.p1Index());

            if (p1_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;

            p1_entry.setFlags(flags);

            return mapping.MapperFlush.init(page);
        }

        fn impl_updateFlags(
            mapper: *Mapper,
            page: paging.Page,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlush {
            return getSelfPtr(mapper).updateFlags(page, flags);
        }

        pub fn setFlagsP4Entry(
            self: *Self,
            page: paging.Page,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlushAll {
            const p4_entry = self.level_4_table.getAtIndex(page.p4Index());
            if (p4_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;
            p4_entry.setFlags(flags);
            return mapping.MapperFlushAll{};
        }

        fn impl_setFlagsP4Entry(
            mapper: *Mapper,
            page: paging.Page,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlushAll {
            return getSelfPtr(mapper).setFlagsP4Entry(page, flags);
        }

        pub fn setFlagsP3Entry(
            self: *Self,
            page: paging.Page,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlushAll {
            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return mapping.FlagUpdateError.PageNotMapped,
            };

            const p3_entry = p3.getAtIndex(page.p3Index());
            if (p3_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;
            p3_entry.setFlags(flags);
            return mapping.MapperFlushAll{};
        }

        fn impl_setFlagsP3Entry(
            mapper: *Mapper,
            page: paging.Page,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlushAll {
            return getSelfPtr(mapper).setFlagsP3Entry(page, flags);
        }

        pub fn setFlagsP2Entry(
            self: *Self,
            page: paging.Page,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlushAll {
            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return mapping.FlagUpdateError.PageNotMapped,
            };
            const p2 = page_table_walker.nextTable(self.context, p3.getAtIndex(page.p3Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.FlagUpdateError.ParentEntryHugePage,
                PageTableWalkError.NotMapped => return mapping.FlagUpdateError.PageNotMapped,
            };

            const p2_entry = p2.getAtIndex(page.p2Index());
            if (p2_entry.isUnused()) return mapping.FlagUpdateError.PageNotMapped;
            p2_entry.setFlags(flags);
            return mapping.MapperFlushAll{};
        }

        fn impl_setFlagsP2Entry(
            mapper: *Mapper,
            page: paging.Page,
            flags: paging.PageTableFlags,
        ) mapping.FlagUpdateError!mapping.MapperFlushAll {
            return getSelfPtr(mapper).setFlagsP2Entry(page, flags);
        }

        pub fn translatePage(self: *const Self, page: paging.Page) mapping.TranslateError!paging.PhysFrame {
            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(page.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.TranslateError.InvalidFrameAddress,
                PageTableWalkError.NotMapped => return mapping.TranslateError.NotMapped,
            };
            const p2 = page_table_walker.nextTable(self.context, p3.getAtIndex(page.p3Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.TranslateError.InvalidFrameAddress,
                PageTableWalkError.NotMapped => return mapping.TranslateError.NotMapped,
            };
            const p1 = page_table_walker.nextTable(self.context, p2.getAtIndex(page.p2Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => return mapping.TranslateError.InvalidFrameAddress,
                PageTableWalkError.NotMapped => return mapping.TranslateError.NotMapped,
            };

            const p1_entry = p1.getAtIndex(page.p1Index());

            if (p1_entry.isUnused()) return mapping.TranslateError.NotMapped;

            return paging.PhysFrame.fromStartAddress(p1_entry.getAddr()) catch |err| return mapping.TranslateError.InvalidFrameAddress;
        }

        fn impl_translatePage(mapper: *Mapper, page: paging.Page) mapping.TranslateError!paging.PhysFrame {
            return getSelfPtr(mapper).translatePage(page);
        }

        pub fn translate(self: *const Self, addr: x86_64.VirtAddr) mapping.TranslateError!mapping.TranslateResult {
            const p3 = page_table_walker.nextTable(self.context, self.level_4_table.getAtIndex(addr.p4Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => @panic("level 4 entry has huge page bit set"),
                PageTableWalkError.NotMapped => return mapping.TranslateError.NotMapped,
            };

            const p2 = page_table_walker.nextTable(self.context, p3.getAtIndex(addr.p3Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => {
                    const entry = p3.getAtIndex(addr.p3Index());
                    const frame = paging.PhysFrame1GiB.containingAddress(entry.getAddr());
                    const offset = addr.value & 0o777_777_7777;
                    return mapping.TranslateResult{
                        .Frame1GiB = .{
                            .frame = frame,
                            .offset = offset,
                            .flags = entry.getFlags(),
                        },
                    };
                },
                PageTableWalkError.NotMapped => return mapping.TranslateError.NotMapped,
            };

            const p1 = page_table_walker.nextTable(self.context, p2.getAtIndex(addr.p2Index())) catch |err| switch (err) {
                PageTableWalkError.MappedToHugePage => {
                    const entry = p2.getAtIndex(addr.p2Index());
                    const frame = paging.PhysFrame2MiB.containingAddress(entry.getAddr());
                    const offset = addr.value & 0o777_7777;
                    return mapping.TranslateResult{
                        .Frame2MiB = .{
                            .frame = frame,
                            .offset = offset,
                            .flags = entry.getFlags(),
                        },
                    };
                },
                PageTableWalkError.NotMapped => {
                    return mapping.TranslateError.NotMapped;
                },
            };

            const p1_entry = p1.getAtIndex(addr.p1Index());

            if (p1_entry.isUnused()) return mapping.TranslateError.NotMapped;

            const frame = paging.PhysFrame.fromStartAddress(p1_entry.getAddr()) catch |err| return mapping.TranslateError.InvalidFrameAddress;

            return mapping.TranslateResult{
                .Frame4KiB = .{
                    .frame = frame,
                    .offset = @as(u64, addr.pageOffset().value),
                    .flags = p1_entry.getFlags(),
                },
            };
        }

        fn impl_translate(mapper: *Mapper, addr: x86_64.VirtAddr) mapping.TranslateError!mapping.TranslateResult {
            return getSelfPtr(mapper).translate(addr);
        }

        /// Translates the given virtual address to the physical address that it maps to.
        ///
        /// Returns `None` if there is no valid mapping for the given address.
        ///
        /// This is a convenience method. For more information about a mapping see the
        /// `translate` function.
        pub fn translateAddr(self: *const Self, addr: x86_64.VirtAddr) ?x86_64.PhysAddr {
            return switch (self.translate(addr) catch return null) {
                .Frame4KiB => |res| x86_64.PhysAddr.initPanic(res.frame.start_address.value + res.offset),
                .Frame2MiB => |res| x86_64.PhysAddr.initPanic(res.frame.start_address.value + res.offset),
                .Frame1GiB => |res| x86_64.PhysAddr.initPanic(res.frame.start_address.value + res.offset),
            };
        }

        fn makeMapper() Mapper {
            return .{
                .z_impl_mapToWithTableFlags1GiB = impl_mapToWithTableFlags1GiB,
                .z_impl_unmap1GiB = impl_unmap1GiB,
                .z_impl_updateFlags1GiB = impl_updateFlags1GiB,
                .z_impl_setFlagsP4Entry1GiB = impl_setFlagsP4Entry1GiB,
                .z_impl_translatePage1GiB = impl_translatePage1GiB,
                .z_impl_mapToWithTableFlags2MiB = impl_mapToWithTableFlags2MiB,
                .z_impl_unmap2MiB = impl_unmap2MiB,
                .z_impl_updateFlags2MiB = impl_updateFlags2MiB,
                .z_impl_setFlagsP4Entry2MiB = impl_setFlagsP4Entry2MiB,
                .z_impl_setFlagsP3Entry2MiB = impl_setFlagsP3Entry2MiB,
                .z_impl_translatePage2MiB = impl_translatePage2MiB,
                .z_impl_mapToWithTableFlags = impl_mapToWithTableFlags,
                .z_impl_unmap = impl_unmap,
                .z_impl_updateFlags = impl_updateFlags,
                .z_impl_setFlagsP4Entry = impl_setFlagsP4Entry,
                .z_impl_setFlagsP3Entry = impl_setFlagsP3Entry,
                .z_impl_setFlagsP2Entry = impl_setFlagsP2Entry,
                .z_impl_translatePage = impl_translatePage,
                .z_impl_translate = impl_translate,
            };
        }

        comptime {
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
                if (frame_allocator.allocate4KiB()) |frame| {
                    entry.setAddr(frame.start_address);
                    entry.setFlags(insert_flags);
                    created = true;
                } else {
                    return PageTableCreateError.FrameAllocationFailed;
                }
            } else {
                const raw_insert_flags = insert_flags.toU64();
                const raw_entry_flags = entry.getFlags().toU64();
                const combined_raw_flags = raw_insert_flags | raw_entry_flags;

                if (raw_insert_flags != 0 and combined_raw_flags != raw_insert_flags) {
                    entry.setFlags(paging.PageTableFlags.fromU64(combined_raw_flags));
                }
            }

            const page_table = nextTable(context, entry) catch |err| switch (err) {
                error.MappedToHugePage => return PageTableCreateError.MappedToHugePage,
                error.NotMapped => @panic("entry should be mapped at this point"),
            };

            if (created) page_table.zero();

            return page_table;
        }

        comptime {
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

comptime {
    std.testing.refAllDecls(@This());
}
