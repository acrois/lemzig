const std = @import("std");

pub const Message = struct {
    sender: usize,
    recipient: usize,
    data: [64]u8,
};

var message_queue = std.ArrayList(Message).init(std.heap.page_allocator);

pub fn send_message(msg: Message) void {
    // Implement message sending
    _ = message_queue.append(msg);
}

pub fn receive_message() ?Message {
    // Implement message receiving
    if (message_queue.items.len == 0) return null;
    return message_queue.pop();
}
