usingnamespace @import("../../../common.zig");

const paging = structures.paging;

/// A page mapper interface. Page size 4 KiB
pub const Mapper = CreateMapper(paging.PageSize.Size4KiB);

/// A page mapper interface. Page size 2 MiB
pub const Mapper2MiB = CreateMapper(paging.PageSize.Size2MiB);

/// A page mapper interface. Page size 1 GiB
pub const Mapper1GiB = CreateMapper(paging.PageSize.Size1GiB);

fn CreateMapper(comptime page_size: paging.PageSize) type {
    const pageType = switch (page_size) {
        .Size4KiB => paging.Page,
        .Size2MiB => paging.Page2MiB,
        .Size1GiB => paging.Page1GiB,
    };

    const frameType = switch (page_size) {
        .Size4KiB => paging.PhysFrame,
        .Size2MiB => paging.PhysFrame2MiB,
        .Size1GiB => paging.PhysFrame1GiB,
    };

    const frameAllocatorType = switch (page_size) {
        .Size4KiB => paging.FrameAllocator,
        .Size2MiB => paging.FrameAllocator2MiB,
        .Size1GiB => paging.FrameAllocator1GiB,
    };

    const flushType = switch (page_size) {
        .Size4KiB => MapperFlush,
        .Size2MiB => MapperFlush2MiB,
        .Size1GiB => MapperFlush1GiB,
    };

    const unmapResultType = switch (page_size) {
        .Size4KiB => UnmapResult,
        .Size2MiB => UnmapResult2MiB,
        .Size1GiB => UnmapResult1GiB,
    };

    const translateType = switch (page_size) {
        .Size4KiB => TranslateResult,
        .Size2MiB => TranslateResult2MiB,
        .Size1GiB => TranslateResult1GiB,
    };

    return struct {
        const Self = @This();

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
        map_to_with_table_flags: fn (self: *Self, page: pageType, frame: frameType, flags: paging.PageTableFlags, frame_allocator: *frameAllocatorType) MapToError!flushType,

        /// Removes a mapping from the page table and returns the frame that used to be mapped.
        ///
        /// Note that no page tables or pages are deallocated.
        unmap: fn (self: *Self, page: pageType) UnmapError!unmapResultType,

        /// Updates the flags of an existing mapping.
        update_flags: fn (self: *Self, page: pageType, flags: paging.PageTableFlags) FlagUpdateError!flushType,

        /// Set the flags of an existing page level 4 table entry
        set_flags_p4_entry: fn (self: *Self, page: pageType, flags: paging.PageTableFlags) FlagUpdateError!MapperFlushAll,

        /// Set the flags of an existing page level 3 table entry
        set_flags_p3_entry: fn (self: *Self, page: pageType, flags: paging.PageTableFlags) FlagUpdateError!MapperFlushAll,

        /// Set the flags of an existing page level 2 table entry
        set_flags_p2_entry: fn (self: *Self, page: pageType, flags: paging.PageTableFlags) FlagUpdateError!MapperFlushAll,

        /// Return the frame that the specified page is mapped to.
        ///
        /// This function assumes that the page is mapped to a frame of size `S` and returns an
        /// error otherwise.
        translate_page: fn (self: *Self, page: pageType) TranslatePageError!frameType,

        /// Return the frame that the given virtual address is mapped to and the offset within that
        /// frame.
        ///
        /// If the given address has a valid mapping, the mapped frame and the offset within that
        /// frame is returned. Otherwise an error value is returned.
        translate: fn (self: *Self, addr: VirtAddr) TranslateError!translateType,

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
        /// The `map_to_with_table_flags` method gives explicit control over the parent page table flags.
        pub fn map_to(self: *Self, page: pageType, frame: frameType, flags: paging.PageTableFlags, frame_allocator: *frameAllocatorType) MapToError!flushType {
            var parent_table_flags = paging.PageTableFlags.init();
            parent_table_flags.PRESENT = flags.PRESENT;
            parent_table_flags.WRITABLE = flags.WRITABLE;
            parent_table_flags.USER_ACCESSIBLE = flags.USER_ACCESSIBLE;

            return self.map_to_with_table_flags(page, frame, parent_table_flags, frame_allocator);
        }

        /// Maps the given frame to the virtual page with the same address.
        pub fn identity_map(self: *Self, frame: frameType, flags: paging.PageTableFlags, frame_allocator: *frameAllocatorType) MapToError!flushType {
            const page = pageType.containing_address(VirtAddr.init(frame.start_address.value));
            return self.map_to(page, frame, flags, frame_allocator);
        }

        /// Translates the given virtual address to the physical address that it maps to.
        ///
        /// Returns `None` if there is no valid mapping for the given address.
        ///
        /// This is a convenience method. For more information about a mapping see the
        /// `translate` function.
        pub fn translate_addr(self: *Self, addr: VirtAddr) ?PhysAddr {
            if (self.translate(addr)) |result| {
                return PhysAddr.init(result.frame.start_address.value + result.offset);
            }
            return null;
        }
    };
}

/// Unmap result. Page size 4 KiB
pub const UnmapResult = CreateUnmapResult(paging.PageSize.Size4KiB);

/// Unmap result. Page size 2 MiB
pub const UnmapResult2MiB = CreateUnmapResult(paging.PageSize.Size2MiB);

/// Unmap result. Page size 1 GiB
pub const UnmapResult1GiB = CreateUnmapResult(paging.PageSize.Size1GiB);

fn CreateUnmapResult(comptime page_size: paging.PageSize) type {
    const frameType = switch (page_size) {
        .Size4KiB => paging.PhysFrame,
        .Size2MiB => paging.PhysFrame2MiB,
        .Size1GiB => paging.PhysFrame1GiB,
    };

    const flushType = switch (page_size) {
        .Size4KiB => MapperFlush,
        .Size2MiB => MapperFlush2MiB,
        .Size1GiB => MapperFlush1GiB,
    };

    return struct {
        frame: frameType, flush: flushType
    };
}

/// The return value of the `translate` function. Page size 4 KiB
pub const TranslateResult = CreateTranslateResult(paging.PageSize.Size4KiB);

/// The return value of the `translate` function. Page size 2 MiB
pub const TranslateResult2MiB = CreateTranslateResult(paging.PageSize.Size2MiB);

/// The return value of the `translate` function. Page size 1 GiB
pub const TranslateResult1GiB = CreateTranslateResult(paging.PageSize.Size1GiB);

fn CreateTranslateResult(comptime page_size: paging.PageSize) type {
    const frameType = switch (page_size) {
        .Size4KiB => paging.PhysFrame,
        .Size2MiB => paging.PhysFrame2MiB,
        .Size1GiB => paging.PhysFrame1GiB,
    };

    return struct {
        /// The offset whithin the mapped frame.
        frame: frameType, offset: u64
    };
}

/// An error indicating that a `translate` call failed.
pub const TranslateError = error{
    /// The given page is not mapped to a physical frame.
    PageNotMapped,
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
    pub fn flush_all(self: Self) void {
        instructions.tlb.flush_all();
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

fn CreateMapperFlush(comptime page_size: paging.PageSize) type {
    const pageType = switch (page_size) {
        .Size4KiB => paging.Page,
        .Size2MiB => paging.Page2MiB,
        .Size1GiB => paging.Page1GiB,
    };

    return struct {
        const Self = @This();
        page: pageType,

        /// Create a new flush promise
        pub fn init(page: pageType) Self {
            return Self{ .page = page };
        }

        /// Flush the page from the TLB to ensure that the newest mapping is used.
        pub fn flush(self: Self) void {
            instructions.tlb.flush(self.page.start_address);
        }
    };
}

pub const MapToError = error{
    /// An additional frame was needed for the mapping process, but the frame allocator
    /// returned `None`.
    FrameAllocationFailed,
    /// An upper level page table entry has the `HUGE_PAGE` flag set, which means that the
    /// given page is part of an already mapped huge page.
    ParentEntryHugePage,
    /// The given page is already mapped to a physical frame.
    PageAlreadyMapped,
};

/// An error indicating that an `unmap` call failed.
pub const UnmapError = error{
    /// An upper level page table entry has the `HUGE_PAGE` flag set, which means that the
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
    /// An upper level page table entry has the `HUGE_PAGE` flag set, which means that the
    /// given page is part of a huge page and can't be freed individually.
    ParentEntryHugePage,
};

/// An error indicating that an `translate` call failed.
pub const TranslatePageError = error{
    /// The given page is not mapped to a physical frame.
    PageNotMapped,
    /// An upper level page table entry has the `HUGE_PAGE` flag set, which means that the
    /// given page is part of a huge page and can't be freed individually.
    ParentEntryHugePage,
    /// The page table entry for the given page points to an invalid physical address.
    InvalidFrameAddress,
};

test "" {
    std.testing.refAllDecls(@This());
}
