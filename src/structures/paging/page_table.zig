usingnamespace @import("../../common.zig");

/// The number of entries in a page table.
pub const ENTRY_COUNT: usize = 512;

pub const PageOffset = packed struct {
    value: u16,
    
    /// Creates a new offset from the given `u16`. Panics if the passed value is >=4096.
    pub inline fn new(offset: u16) PageOffset {
        std.debug.assert(offset < (1 << 12));
        return PageOffset { .value = offset };
    }
    
    /// Creates a new offset from the given `u16`. Throws away bits if the value is >=4096.
    pub inline fn new_truncate(offset: u16) PageOffset {
        return PageOffset { .value = offset % (1 << 12) };
    }
};

pub const PageTableIndex = packed struct {
    value: u16,
    
    /// Creates a new index from the given `u16`. Panics if the given value is >=ENTRY_COUNT.
    pub inline fn new(index: u16) PageTableIndex {
        std.debug.assert(@as(usize, index) < ENTRY_COUNT);
        return PageTableIndex { .value = index };
    }
    
    /// Creates a new index from the given `u16`. Throws away bits if the value is >=ENTRY_COUNT.
    pub inline fn new_truncate(index: u16) PageTableIndex {
        return PageTableIndex { .value = index % @as(u16, ENTRY_COUNT) };
    }
};
