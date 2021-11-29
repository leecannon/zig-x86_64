const page_table = @import("page_table.zig");
pub const PAGE_TABLE_ENTRY_COUNT = page_table.PAGE_TABLE_ENTRY_COUNT;
pub const FrameError = page_table.FrameError;
pub const PageTableEntry = page_table.PageTableEntry;
pub const PageTableFlags = page_table.PageTableFlags;
pub const PageTable = page_table.PageTable;
pub const PageTableIndex = page_table.PageTableIndex;
pub const PageOffset = page_table.PageOffset;
pub const PageTableLevel = page_table.PageTableLevel;

const frame = @import("frame.zig");

pub const PhysFrame = frame.PhysFrame;
pub const PhysFrame2MiB = frame.PhysFrame2MiB;
pub const PhysFrame1GiB = frame.PhysFrame1GiB;
pub const PhysFrameError = frame.PhysFrameError;
pub const PhysFrameIterator = frame.PhysFrameIterator;
pub const PhysFrameIterator2MiB = frame.PhysFrameIterator2MiB;
pub const PhysFrameIterator1GiB = frame.PhysFrameIterator1GiB;
pub const PhysFrameRange = frame.PhysFrameRange;
pub const PhysFrameRange2MiB = frame.PhysFrameRange2MiB;
pub const PhysFrameRange1GiB = frame.PhysFrameRange1GiB;
pub const PhysFrameRangeInclusive = frame.PhysFrameRangeInclusive;
pub const PhysFrameRange2MiBInclusive = frame.PhysFrameRange2MiBInclusive;
pub const PhysFrameRange1GiBInclusive = frame.PhysFrameRange1GiBInclusive;

const page = @import("page.zig");

pub const PageSize = page.PageSize;
pub const Page = page.Page;
pub const Page2MiB = page.Page2MiB;
pub const Page1GiB = page.Page1GiB;
pub const PageError = page.PageError;
pub const pageFromTableIndices = page.pageFromTableIndices;
pub const pageFromTableIndices2MiB = page.pageFromTableIndices2MiB;
pub const pageFromTableIndices1GiB = page.pageFromTableIndices1GiB;
pub const PageRange = page.PageRange;
pub const PageRange2MiB = page.PageRange2MiB;
pub const PageRange1GiB = page.PageRange1GiB;
pub const PageRangeInclusive = page.PageRangeInclusive;
pub const PageRange2MiBInclusive = page.PageRange2MiBInclusive;
pub const PageRange1GiBInclusive = page.PageRange1GiBInclusive;
pub const PageIterator = page.PageIterator;
pub const PageIterator2MiB = page.PageIterator2MiB;
pub const PageIterator1GiB = page.PageIterator1GiB;

const frame_alloc = @import("frame_alloc.zig");
pub const FrameAllocator = frame_alloc.FrameAllocator;

pub const mapping = @import("mapping/mapping.zig");

comptime {
    @import("std").testing.refAllDecls(@This());
}
