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

pub export var memmap_request: limine.MemoryMapRequest = .{};

pub export var smp_request: limine.SmpRequest = .{};

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
}

const pit_frequency: u32 = 1193182; // Standard PIT frequency

fn init_pit(frequency: u16) void {
    const divisor: u16 = @intCast(pit_frequency / frequency);
    asm volatile (
        \\cli
        \\movb $0x36, %%al
        \\outb %%al, $0x43
        \\movw %[divisor], %%ax
        \\outb %%al, $0x40
        \\movb %%ah, %%al
        \\outb %%al, $0x40
        \\sti
        :
        : [divisor] "r" (divisor),
        : "ax"
    );
}

fn read_pit_count() u16 {
    var low: u8 = undefined;
    var high: u8 = undefined;
    asm volatile (
        \\cli
        \\movb $0x00, %%al
        \\outb %%al, $0x43
        \\inb $0x40, %%al
        \\movb %%al, %[low]
        \\inb $0x40, %%al
        \\movb %%al, %[high]
        \\sti
        : [low] "=r" (low),
          [high] "=r" (high),
        :
        : "al"
    );
    return (@as(u16, high) << 8) | low;
}

fn read_tsc() u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;
    asm volatile ("rdtsc"
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
    );
    return (@as(u64, high) << 32) | low;
}

pub fn estimate_cpu_frequency() u64 {
    const calibration_time_ms = 100;
    const pit_freq = 1000; // 1kHz, meaning each tick is 1ms

    init_pit(pit_freq);

    const start_tsc = read_tsc();
    const start_pit = read_pit_count();

    // Wait for calibration_time_ms
    while (true) {
        const current_pit = read_pit_count();
        const elapsed = if (current_pit <= start_pit)
            start_pit - current_pit
        else
            (0xFFFF - current_pit) + start_pit;

        if (elapsed >= calibration_time_ms) break;
    }

    const end_tsc = read_tsc();
    const tsc_delta = end_tsc - start_tsc;

    // Calculate frequency in Hz
    return (tsc_delta * 1000) / calibration_time_ms;
}
