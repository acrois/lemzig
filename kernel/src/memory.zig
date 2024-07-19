const std = @import("std");
const limine = @import("limine");
const serial = @import("serial.zig");
const kernel = @import("kernel.zig");

const PageSize = 4096;
const MinAllocSize = 16;

const AllocHeader = struct {
    size: usize,
    next: ?*AllocHeader,
    is_free: bool,
};

const Allocator = struct {
    free_list: ?*AllocHeader,
    heap_start: usize,
    heap_end: usize,

    pub fn init(start: usize, end: usize) Allocator {
        var self = Allocator{
            .free_list = null,
            .heap_start = start,
            .heap_end = end,
        };
        self.init_free_list();
        return self;
    }

    fn init_free_list(self: *Allocator) void {
        const aligned_start = std.mem.alignForward(self.heap_start, @alignOf(AllocHeader));
        const header: *AllocHeader = @ptrFromInt(aligned_start);
        header.* = .{
            .size = self.heap_end - aligned_start,
            .next = null,
            .is_free = true,
        };
        self.free_list = header;
    }

    pub fn alloc(self: *Allocator, size: usize) ?[*]u8 {
        const aligned_size = std.mem.alignForward(size + @sizeOf(AllocHeader), MinAllocSize);
        var current = self.free_list;
        var prev: ?*AllocHeader = null;

        while (current) |node| : (current = node.next) {
            if (node.is_free and node.size >= aligned_size) {
                if (node.size > aligned_size + @sizeOf(AllocHeader)) {
                    // Split the block
                    const new_node: *AllocHeader = @ptrFromInt(@intFromPtr(node) + aligned_size);
                    new_node.* = .{
                        .size = node.size - aligned_size,
                        .next = node.next,
                        .is_free = true,
                    };
                    node.size = aligned_size;
                    node.next = new_node;
                }

                node.is_free = false;

                if (prev) |p| {
                    p.next = node.next;
                } else {
                    self.free_list = node.next;
                }

                return @ptrFromInt(@intFromPtr(node) + @sizeOf(AllocHeader));
            }
            prev = node;
        }

        return null; // Out of memory
    }

    pub fn free(self: *Allocator, ptr: [*]u8) void {
        const header: *AllocHeader = @ptrFromInt(@intFromPtr(ptr) - @sizeOf(AllocHeader));
        header.is_free = true;

        // Attempt to merge with adjacent free blocks
        var current = self.free_list;
        var prev: ?*AllocHeader = null;

        while (current) |node| : (current = node.next) {
            if (@intFromPtr(node) > @intFromPtr(header)) {
                // Insert the freed block into the free list
                header.next = node;
                if (prev) |p| {
                    p.next = header;
                } else {
                    self.free_list = header;
                }

                // Merge with next block if it's free
                if (node.is_free) {
                    header.size += node.size;
                    header.next = node.next;
                }

                // Merge with previous block if it's free
                if (prev) |p| {
                    if (p.is_free) {
                        p.size += header.size;
                        p.next = header.next;
                    }
                }

                return;
            }
            prev = node;
        }

        // If we get here, the freed block is at the end of the heap
        if (prev) |p| {
            p.next = header;
            if (p.is_free) {
                p.size += header.size;
                p.next = header.next;
            }
        } else {
            self.free_list = header;
        }
    }

    pub fn print_memory_map(self: *Allocator) void {
        var current = self.free_list;
        var index: usize = 0;
        while (current) |node| : (current = node.next) {
            var buffer: [100]u8 = undefined;
            const info = std.fmt.bufPrint(&buffer, "Block {}: Address: 0x{X}, Size: {} bytes, Is Free: {}\n", .{ index, @intFromPtr(node), node.size, node.is_free }) catch "Error formatting memory info";
            serial.write_string(serial.SERIAL_PORT_COM1, info);
            index += 1;
        }
    }
};

pub var kernel_allocator: Allocator = undefined;

pub fn init_memory() void {
    if (kernel.memmap_request.response) |memmap| {
        const entries = memmap.entries()[0..memmap.entry_count];
        var largest_free_area: ?limine.MemoryMapEntry = null;

        for (entries) |entry| {
            if (entry.kind == .usable) {
                if (largest_free_area == null or entry.length > largest_free_area.?.length) {
                    largest_free_area = entry.*;
                }
            }
        }

        if (largest_free_area) |area| {
            kernel_allocator = Allocator.init(area.base, area.base + area.length);
            var buffer: [100]u8 = undefined;
            const info = std.fmt.bufPrint(&buffer, "Initialized memory allocator. Heap start: 0x{X}, Heap end: 0x{X}\n", .{ kernel_allocator.heap_start, kernel_allocator.heap_end }) catch "Error formatting memory info";
            serial.write_string(serial.SERIAL_PORT_COM1, info);
        } else {
            @panic("No usable memory area found!");
        }
    } else {
        @panic("No memory map provided by Limine!");
    }
}

pub fn alloc_user_space_program(size: usize) ?[*]u8 {
    return kernel_allocator.alloc(size);
}

pub fn free_user_space_program(ptr: [*]u8) void {
    kernel_allocator.free(ptr);
}
