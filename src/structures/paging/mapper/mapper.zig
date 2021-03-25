usingnamespace @import("../../../common.zig");

pub usingnamespace @import("mapped_page_table.zig");
pub usingnamespace @import("recursive_page_table.zig");

const physToVirt = struct {
    pub fn physToVirt(offset: VirtAddr, phys_frame: paging.PhysFrame) *paging.PageTable {
        return VirtAddr.initPanic(offset.value + phys_frame.start_address.value).toPtr(*paging.PageTable);
    }
}.physToVirt;

pub fn OffsetPageTable() type {
    return MappedPageTable(VirtAddr, physToVirt);
}

const paging = structures.paging;

pub const Mapper = struct {
    // This is the most annoying code ive ever written...
    // All just to have something that is trivial in most languages; an interface
    impl_mapToWithTableFlags1GiB: fn (
        mapper: *Mapper,
        page: paging.Page1GiB,
        frame: paging.PhysFrame1GiB,
        flags: paging.PageTableFlags,
        parent_table_flags: paging.PageTableFlags,
        frame_allocator: *paging.FrameAllocator,
    ) paging.MapToError!paging.MapperFlush1GiB,

    impl_unmap1GiB: fn (
        mapper: *Mapper,
        page: paging.Page1GiB,
    ) paging.UnmapError!paging.UnmapResult1GiB,

    impl_updateFlags1GiB: fn (
        mapper: *Mapper,
        page: paging.Page1GiB,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlush1GiB,

    impl_setFlagsP4Entry1GiB: fn (
        mapper: *Mapper,
        page: paging.Page1GiB,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlushAll,

    impl_translatePage1GiB: fn (
        mapper: *Mapper,
        page: paging.Page1GiB,
    ) paging.TranslateError!paging.PhysFrame1GiB,

    impl_mapToWithTableFlags2MiB: fn (
        mapper: *Mapper,
        page: paging.Page2MiB,
        frame: paging.PhysFrame2MiB,
        flags: paging.PageTableFlags,
        parent_table_flags: paging.PageTableFlags,
        frame_allocator: *paging.FrameAllocator,
    ) paging.MapToError!paging.MapperFlush2MiB,

    impl_unmap2MiB: fn (
        mapper: *Mapper,
        page: paging.Page2MiB,
    ) paging.UnmapError!paging.UnmapResult2MiB,

    impl_updateFlags2MiB: fn (
        mapper: *Mapper,
        page: paging.Page2MiB,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlush2MiB,

    impl_setFlagsP4Entry2MiB: fn (
        mapper: *Mapper,
        page: paging.Page2MiB,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlushAll,

    impl_setFlagsP3Entry2MiB: fn (
        mapper: *Mapper,
        page: paging.Page2MiB,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlushAll,

    impl_translatePage2MiB: fn (
        mapper: *Mapper,
        page: paging.Page2MiB,
    ) paging.TranslateError!paging.PhysFrame2MiB,

    impl_mapToWithTableFlags: fn (
        mapper: *Mapper,
        page: paging.Page,
        frame: paging.PhysFrame,
        flags: paging.PageTableFlags,
        parent_table_flags: paging.PageTableFlags,
        frame_allocator: *paging.FrameAllocator,
    ) paging.MapToError!paging.MapperFlush,

    impl_unmap: fn (
        mapper: *Mapper,
        page: paging.Page,
    ) paging.UnmapError!paging.UnmapResult,

    impl_updateFlags: fn (
        mapper: *Mapper,
        page: paging.Page,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlush,

    impl_setFlagsP4Entry: fn (
        mapper: *Mapper,
        page: paging.Page,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlushAll,

    impl_setFlagsP3Entry: fn (
        mapper: *Mapper,
        page: paging.Page,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlushAll,

    impl_setFlagsP2Entry: fn (
        mapper: *Mapper,
        page: paging.Page,
        flags: paging.PageTableFlags,
    ) paging.FlagUpdateError!paging.MapperFlushAll,

    impl_translatePage: fn (
        mapper: *Mapper,
        page: paging.Page,
    ) paging.TranslateError!paging.PhysFrame,

    impl_translate: fn (
        mapper: *Mapper,
        addr: VirtAddr,
    ) paging.TranslateError!paging.TranslateResult,

    /// Creates a new mapping in the page table.
    ///
    /// This function might need additional physical frames to create new page tables. These
    /// frames are allocated from the `allocator` argument. At most three frames are required.
    ///
    /// Parent page table entries are automatically updated with `PRESENT | WRITABLE | USER_ACCESSIBLE`
    /// if present in the `PageTableFlags`. Depending on the used mapper implementation
    /// the `PRESENT` and `WRITABLE` flags might be set for parent tables,
    /// even if they are not set in `PageTableFlags`.
    ///
    /// The `mapToWithTableFlags` method gives explicit control over the parent page table flags.
    pub fn mapTo(
        mapper: *Mapper,
        comptime size: paging.PageSize,
        page: paging.CreatePage(size),
        frame: paging.CreatePhysFrame(size),
        flags: paging.PageTableFlags,
        frame_allocator: *paging.FrameAllocator,
    ) callconv(.Inline) paging.MapToError!paging.CreateMapperFlush(size) {
        const parent_table_flags = paging.PageTableFlags.init(
            flags.value &
                (paging.PageTableFlags.PRESENT | paging.PageTableFlags.WRITABLE | paging.PageTableFlags.USER_ACCESSIBLE),
        );

        return switch (size) {
            .Size4KiB => mapper.impl_mapToWithTableFlags(mapper, page, frame, flags, parent_table_flags, frame_allocator),
            .Size2MiB => mapper.impl_mapToWithTableFlags2MiB(mapper, page, frame, flags, parent_table_flags, frame_allocator),
            .Size1GiB => mapper.impl_mapToWithTableFlags1GiB(mapper, page, frame, flags, parent_table_flags, frame_allocator),
        };
    }

    /// Maps the given frame to the virtual page with the same address.
    pub fn identityMap(
        mapper: *Mapper,
        comptime size: paging.PageSize,
        frame: paging.CreatePhysFrame(size),
        flags: paging.PageTableFlags,
        frame_allocator: *paging.FrameAllocator,
    ) paging.MapToError!paging.CreateMapperFlush(size) {
        return mapper.mapTo(
            size,
            paging.CreatePage(size).containingAddress(VirtAddr.initPanic(frame.start_address.value)),
            frame,
            flags,
            frame_allocator,
        );
    }

    /// Translates the given virtual address to the physical address that it maps to.
    ///
    /// Returns `None` if there is no valid mapping for the given address.
    ///
    /// This is a convenience method. For more information about a mapping see the
    /// `translate` function.
    pub fn translateAddr(mapper: *Mapper, addr: VirtAddr) ?PhysAddr {
        return switch (mapper.translate(addr) catch return null) {
            .Frame4KiB => |res| PhysAddr.initPanic(res.frame.start_address.value + res.offset),
            .Frame2MiB => |res| PhysAddr.initPanic(res.frame.start_address.value + res.offset),
            .Frame1GiB => |res| PhysAddr.initPanic(res.frame.start_address.value + res.offset),
        };
    }

    /// Return the frame that the given virtual address is mapped to and the offset within that
    /// frame.
    ///
    /// If the given address has a valid mapping, the mapped frame and the offset within that
    /// frame is returned. Otherwise an error value is returned.
    pub fn translate(
        mapper: *Mapper,
        addr: VirtAddr,
    ) callconv(.Inline) paging.TranslateError!paging.TranslateResult {
        return mapper.impl_translate(mapper, addr);
    }

    /// Return the frame that the specified page is mapped to.
    pub fn translatePage(
        mapper: *Mapper,
        comptime size: paging.PageSize,
        page: paging.CreatePage(size),
    ) callconv(.Inline) paging.TranslateError!paging.CreatePhysFrame(size) {
        return switch (size) {
            .Size4KiB => mapper.impl_translatePage(mapper, page),
            .Size2MiB => mapper.impl_translatePage2MiB(mapper, page),
            .Size1GiB => mapper.impl_translatePage1GiB(mapper, page),
        };
    }

    /// Set the flags of an existing page table level 2 entry
    pub fn setFlagsP2Entry(
        mapper: *Mapper,
        comptime size: paging.PageSize,
        page: paging.CreatePage(size),
        flags: paging.PageTableFlags,
    ) callconv(.Inline) paging.FlagUpdateError!paging.MapperFlushAll {
        return switch (size) {
            .Size4KiB => mapper.impl_setFlagsP2Entry(mapper, page, flags),
            .Size2MiB => paging.FlagUpdateError.ParentEntryHugePage,
            .Size1GiB => paging.FlagUpdateError.ParentEntryHugePage,
        };
    }

    /// Set the flags of an existing page table level 3 entry
    pub fn setFlagsP3Entry(
        mapper: *Mapper,
        comptime size: paging.PageSize,
        page: paging.CreatePage(size),
        flags: paging.PageTableFlags,
    ) callconv(.Inline) paging.FlagUpdateError!paging.MapperFlushAll {
        return switch (size) {
            .Size4KiB => mapper.impl_setFlagsP3Entry(mapper, page, flags),
            .Size2MiB => mapper.impl_setFlagsP3Entry2MiB(mapper, page, flags),
            .Size1GiB => paging.FlagUpdateError.ParentEntryHugePage,
        };
    }

    /// Set the flags of an existing page table level 4 entry
    pub fn setFlagsP4Entry(
        mapper: *Mapper,
        comptime size: paging.PageSize,
        page: paging.CreatePage(size),
        flags: paging.PageTableFlags,
    ) callconv(.Inline) paging.FlagUpdateError!paging.MapperFlushAll {
        return switch (size) {
            .Size4KiB => mapper.impl_setFlagsP4Entry(mapper, page, flags),
            .Size2MiB => mapper.impl_setFlagsP4Entry2MiB(mapper, page, flags),
            .Size1GiB => mapper.impl_setFlagsP4Entry1GiB(mapper, page, flags),
        };
    }

    /// Updates the flags of an existing mapping.
    pub fn updateFlags(
        mapper: *Mapper,
        comptime size: paging.PageSize,
        page: paging.CreatePage(size),
        flags: paging.PageTableFlags,
    ) callconv(.Inline) paging.FlagUpdateError!paging.CreateMapperFlush(size) {
        return switch (size) {
            .Size4KiB => mapper.impl_updateFlags(mapper, page, flags),
            .Size2MiB => mapper.impl_updateFlags2MiB(mapper, page, flags),
            .Size1GiB => mapper.impl_updateFlags1GiB(mapper, page, flags),
        };
    }

    /// Removes a mapping from the page table and returns the frame that used to be mapped.
    ///
    /// Note that no page tables or pages are deallocated.
    pub fn unmap(
        mapper: *Mapper,
        comptime size: paging.PageSize,
        page: paging.CreatePage(size),
    ) callconv(.Inline) paging.UnmapError!paging.CreateUnmapResult(size) {
        return switch (size) {
            .Size4KiB => mapper.impl_unmap(mapper, page),
            .Size2MiB => mapper.impl_unmap2MiB(mapper, page),
            .Size1GiB => mapper.impl_unmap1GiB(mapper, page),
        };
    }

    /// Creates a new mapping in the page table.
    ///
    /// This function might need additional physical frames to create new page tables. These
    /// frames are allocated from the `allocator` argument. At most three frames are required.
    ///
    /// The flags of the parent table(s) can be explicitly specified. Those flags are used for
    /// newly created table entries, and for existing entries the flags are added.
    ///
    /// Depending on the used mapper implementation, the `PRESENT` and `WRITABLE` flags might
    /// be set for parent tables, even if they are not specified in `parent_table_flags`.
    pub fn mapToWithTableFlags(
        mapper: *Mapper,
        comptime size: paging.PageSize,
        page: paging.CreatePage(size),
        frame: paging.CreatePhysFrame(size),
        flags: paging.PageTableFlags,
        parent_table_flags: paging.PageTableFlags,
        frame_allocator: *paging.FrameAllocator,
    ) callconv(.Inline) paging.MapToError!paging.CreateMapperFlush(size) {
        return switch (size) {
            .Size4KiB => mapper.impl_mapToWithTableFlags(mapper, page, frame, flags, parent_table_flags, frame_allocator),
            .Size2MiB => mapper.impl_mapToWithTableFlags2MiB(mapper, page, frame, flags, parent_table_flags, frame_allocator),
            .Size1GiB => mapper.impl_mapToWithTableFlags1GiB(mapper, page, frame, flags, parent_table_flags, frame_allocator),
        };
    }

    test "" {
        std.testing.refAllDecls(@This());
    }
};

/// Unmap result. Page size 4 KiB
pub const UnmapResult = CreateUnmapResult(paging.PageSize.Size4KiB);

/// Unmap result. Page size 2 MiB
pub const UnmapResult2MiB = CreateUnmapResult(paging.PageSize.Size2MiB);

/// Unmap result. Page size 1 GiB
pub const UnmapResult1GiB = CreateUnmapResult(paging.PageSize.Size1GiB);

pub fn CreateUnmapResult(comptime page_size: paging.PageSize) type {
    const frame_type = switch (page_size) {
        .Size4KiB => paging.PhysFrame,
        .Size2MiB => paging.PhysFrame2MiB,
        .Size1GiB => paging.PhysFrame1GiB,
    };

    const flush_type = switch (page_size) {
        .Size4KiB => MapperFlush,
        .Size2MiB => MapperFlush2MiB,
        .Size1GiB => MapperFlush1GiB,
    };

    return struct { frame: frame_type, flush: flush_type };
}

pub const TranslateResultType = enum {
    Frame4KiB,
    Frame2MiB,
    Frame1GiB,
};

pub const TranslateResult = union(TranslateResultType) {
    Frame4KiB: TranslateResultContents,
    Frame2MiB: TranslateResult2MiBContents,
    Frame1GiB: TranslateResult1GiBContents,
};

pub const TranslateResultContents = CreateTranslateResultContents(paging.PageSize.Size4KiB);

pub const TranslateResult2MiBContents = CreateTranslateResultContents(paging.PageSize.Size2MiB);

pub const TranslateResult1GiBContents = CreateTranslateResultContents(paging.PageSize.Size1GiB);

pub fn CreateTranslateResultContents(comptime page_size: paging.PageSize) type {
    const frame_type = switch (page_size) {
        .Size4KiB => paging.PhysFrame,
        .Size2MiB => paging.PhysFrame2MiB,
        .Size1GiB => paging.PhysFrame1GiB,
    };

    return struct {
        /// The mapped frame.
        frame: frame_type,
        /// The offset whithin the mapped frame.
        offset: u64,
        /// The flags for the frame.
        flags: paging.PageTableFlags,
    };
}

/// An error indicating that a `translate` call failed.
pub const TranslateError = error{
    /// The given page is not mapped to a physical frame.
    NotMapped,
    /// The page table entry for the given page points to an invalid physical address.
    InvalidFrameAddress,
};

/// This type represents a change of a page table requiring a complete TLB flush
///
/// The old mapping might be still cached in the translation lookaside buffer (TLB), so it needs
/// to be flushed from the TLB before it's accessed. This type is returned from a function that
/// made the change to ensure that the TLB flush is not forgotten.
pub const MapperFlushAll = struct {
    /// Flush all pages from the TLB to ensure that the newest mapping is used.
    pub fn flushAll(self: Self) void {
        instructions.tlb.flushAll();
    }
};

/// This type represents a page whose mapping has changed in the page table. Page size 4 KiB
///
/// The old mapping might be still cached in the translation lookaside buffer (TLB), so it needs
/// to be flushed from the TLB before it's accessed. This type is returned from function that
/// change the mapping of a page to ensure that the TLB flush is not forgotten.
pub const MapperFlush = CreateMapperFlush(paging.PageSize.Size4KiB);

/// This type represents a page whose mapping has changed in the page table. Page size 2 MiB
///
/// The old mapping might be still cached in the translation lookaside buffer (TLB), so it needs
/// to be flushed from the TLB before it's accessed. This type is returned from function that
/// change the mapping of a page to ensure that the TLB flush is not forgotten.
pub const MapperFlush2MiB = CreateMapperFlush(paging.PageSize.Size2MiB);

/// This type represents a page whose mapping has changed in the page table. Page size 1 GiB
///
/// The old mapping might be still cached in the translation lookaside buffer (TLB), so it needs
/// to be flushed from the TLB before it's accessed. This type is returned from function that
/// change the mapping of a page to ensure that the TLB flush is not forgotten.
pub const MapperFlush1GiB = CreateMapperFlush(paging.PageSize.Size1GiB);

pub fn CreateMapperFlush(comptime page_size: paging.PageSize) type {
    const page_type = switch (page_size) {
        .Size4KiB => paging.Page,
        .Size2MiB => paging.Page2MiB,
        .Size1GiB => paging.Page1GiB,
    };

    return struct {
        const Self = @This();
        page: page_type,

        /// Create a new flush promise
        pub fn init(page: page_type) Self {
            return Self{ .page = page };
        }

        /// Flush the page from the TLB to ensure that the newest mapping is used.
        pub fn flush(self: Self) void {
            instructions.tlb.flush(self.page.start_address);
        }

        test "" {
            std.testing.refAllDecls(@This());
        }
    };
}

pub const MapToError = error{
    /// An additional frame was needed for the mapping process, but the frame allocator
    /// returned `None`.
    FrameAllocationFailed,
    /// An upper level page table entry has the `huge_page` flag set, which means that the
    /// given page is part of an already mapped huge page.
    ParentEntryHugePage,
    /// The given page is already mapped to a physical frame.
    PageAlreadyMapped,
};

/// An error indicating that an `unmap` call failed.
pub const UnmapError = error{
    /// An upper level page table entry has the `huge_page` flag set, which means that the
    /// given page is part of a huge page and can't be freed individually.
    ParentEntryHugePage,
    /// The given page is not mapped to a physical frame.
    PageNotMapped,
    /// The page table entry for the given page points to an invalid physical address.
    InvalidFrameAddress,
};

/// An error indicating that an `update_flags` call failed.
pub const FlagUpdateError = error{
    /// The given page is not mapped to a physical frame.
    PageNotMapped,
    /// An upper level page table entry has the `huge_page` flag set, which means that the
    /// given page is part of a huge page and can't be freed individually.
    ParentEntryHugePage,
};

/// An error indicating that an `translate` call failed.
pub const TranslatePageError = error{
    /// The given page is not mapped to a physical frame.
    PageNotMapped,
    /// An upper level page table entry has the `huge_page` flag set, which means that the
    /// given page is part of a huge page and can't be freed individually.
    ParentEntryHugePage,
    /// The page table entry for the given page points to an invalid physical address.
    InvalidFrameAddress,
};

test "" {
    std.testing.refAllDecls(@This());
    const offsetPageTable = OffsetPageTable().init(VirtAddr.zero(), @intToPtr(*paging.PageTable, 4096));
}
