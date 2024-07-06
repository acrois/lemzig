const std = @import("std");

pub const PageAllocator = struct {
    base: usize,
    num_pages: usize,
    free_list: []bool, // Track which pages are free

    pub fn init(base: usize, num_pages: usize) PageAllocator {
        return PageAllocator{
            .base = base,
            .num_pages = num_pages,
            .free_list = std.heap.page_allocator.alloc(bool, num_pages) catch unreachable,
        };
    }

    pub fn allocate_page(self: *PageAllocator) ?*u8 {
        for (self.free_list, 0..) |*is_free, index| {
            if (is_free) {
                is_free.* = false;
                return @ptrCast(self.base + index * 4096);
            }
        }
        return null; // No free pages
    }

    pub fn free_page(self: *PageAllocator, page: *u8) void {
        const index = (@as(usize, @intCast(page)) - self.base) / 4096;
        self.free_list[index] = true;
    }
};

var global_allocator: PageAllocator = undefined;

pub fn init(base: usize, num_pages: usize) void {
    global_allocator = PageAllocator.init(base, num_pages);
}

pub fn allocate_page() ?*u8 {
    return global_allocator.allocate_page();
}

pub fn free_page(page: *u8) void {
    global_allocator.free_page(page);
}

pub fn allocate_stack() ?*u8 {
    const stack_size = 4096;
    const stack = allocate_page() orelse return null;
    return stack + stack_size - @sizeOf(usize);
}
