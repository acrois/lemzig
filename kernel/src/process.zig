const std = @import("std");
const memory = @import("memory.zig");
const context_switch = @import("context_switch.zig");

pub const Process = struct {
    id: usize,
    stack_pointer: *usize,
    // Add other fields as needed (e.g., state, priority)
};

var process_list = std.ArrayList(Process).init(std.heap.page_allocator);
var current_process_index: usize = 0;

pub fn init() void {
    // Initialize process management structures
}

pub fn create_process(entry: fn () void) *Process {
    const new_process = Process{
        .id = process_list.items.len,
        .stack_pointer = memory.allocate_stack(),
    };
    _ = process_list.append(new_process);
    // Initialize the stack with the entry point
    const stack_top = new_process.stack_pointer;
    @as([*]usize, @ptrCast(stack_top))[-1] = @ptrCast(entry);
    return &process_list.items[process_list.items.len - 1];
}

pub fn schedule() void {
    // Simple round-robin scheduler
    const next_process_index = (current_process_index + 1) % process_list.items.len;
    const next_process = &process_list.items[next_process_index];

    context_switch.switch_to(next_process.stack_pointer);

    current_process_index = next_process_index;
}

pub fn get_current_process() *Process {
    return &process_list.items[current_process_index];
}
