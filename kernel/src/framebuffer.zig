const std = @import("std");
const limine = @import("limine");
const kernel = @import("kernel.zig");

pub fn draw(framebuffer_response: *limine.FramebufferResponse) void {
    if (framebuffer_response.framebuffer_count < 1) {
        kernel.done();
    }

    const framebuffer = framebuffer_response.framebuffers()[0];

    for (0..100) |i| {
        const pixel_offset = i * framebuffer.pitch + i * 4;
        @as(*u32, @ptrCast(@alignCast(framebuffer.address + pixel_offset))).* = 0xFFFFFFFF;
    }
}
