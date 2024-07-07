const limine = @import("limine");
const std = @import("std");

// The Limine requests can be placed anywhere, but it is important that
// the compiler does not optimise them away, so, usually, they should
// be made volatile or equivalent. In Zig, `export var` is what we use.
pub export var framebuffer_request: limine.FramebufferRequest = .{};

// Set the base revision to 2, this is recommended as this is the latest
// base revision described by the Limine boot protocol specification.
// See specification for further info.
pub export var base_revision: limine.BaseRevision = .{ .revision = 2 };

pub export var memory_request: limine.MemoryRequest = .{};

pub export var smp_request: limine.SMPRequest = .{};

pub inline fn done() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

pub fn init() void {
    // Ensure the bootloader actually understands our base revision (see spec).
    if (!base_revision.is_supported()) {
        done();
    }

    if (memory_request.response == null) {
        // Handle error
        done();
    }

    if (smp_request.response == null) {
        // Handle error
        done();
    }
}
