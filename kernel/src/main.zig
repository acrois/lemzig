const kernel = @import("kernel.zig");
const serial = @import("serial.zig");
const framebuffer = @import("framebuffer.zig");
const security = @import("security.zig");
const limine = @import("limine");
const std = @import("std");

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

fn estimate_cpu_frequency() u64 {
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

export fn _start() callconv(.C) noreturn {
    kernel.init();
    serial.init(serial.SERIAL_PORT_COM1);
    security.init();

    // Output a test string to the serial port
    serial.write_string(serial.SERIAL_PORT_COM1, "Hello, Serial World!\n");

    // Ensure we got a framebuffer.
    if (kernel.framebuffer_request.response) |framebuffer_response| {
        framebuffer.draw(framebuffer_response);
    }

    if (kernel.smp_request.response) |smp| {
        // We have a valid SMP response
        const cpu_count = smp.cpu_count;

        serial.write_string(serial.SERIAL_PORT_COM1, "CPU Information:\n");

        var buffer: [100]u8 = undefined;
        const estimated_freq = estimate_cpu_frequency() / 1_000_000;
        const freq_str = std.fmt.bufPrint(&buffer, "CPU Base Frequency: {} MHz\n", .{estimated_freq}) catch "Error";
        serial.write_string(serial.SERIAL_PORT_COM1, freq_str);
        const cpu_count_str = std.fmt.bufPrint(&buffer, "Total CPU cores: {}\n", .{cpu_count}) catch "Error";
        serial.write_string(serial.SERIAL_PORT_COM1, cpu_count_str);

        // Iterate through each CPU
        for (smp.cpus()[0..cpu_count]) |cpu| {
            const processor_id = cpu.processor_id;
            const lapic_id = cpu.lapic_id;

            // Note: Limine doesn't directly provide clock speed.
            // You might need to use CPUID or other methods to get this info.

            const cpu_info_str = std.fmt.bufPrint(&buffer, "CPU Core: Processor ID: {}, LAPIC ID: {}\n", .{ processor_id, lapic_id }) catch "Error";
            serial.write_string(serial.SERIAL_PORT_COM1, cpu_info_str);
        }
    } else {
        @panic("No SMP information provided by Limine!");
    }

    if (kernel.memmap_request.response) |memmap| {
        // We have a valid memory map
        const entry_count = memmap.entry_count;
        const entries = memmap.entries()[0..entry_count];

        for (entries) |entry| {
            const kind = @tagName(entry.kind);

            const base = entry.base;
            const length = entry.length;

            var buffer: [64]u8 = undefined;
            const str = std.fmt.bufPrint(&buffer, "kind: {s}, b: {}, l: {}\n", .{ kind, base, length }) catch "Error";
            serial.write_string(serial.SERIAL_PORT_COM1, str);
            // Process each memory map entry
            // switch (entry.kind) {
            //     .usable => {
            //         kind = entry.kind;
            //         // This is usable memory
            //         // Do something with this usable memory region
            //     },
            //     .bootloader_reclaimable => {
            //         // Memory that can be reclaimed after boot
            //     },
            //     .kernel_and_modules => {
            //         // The kernel and modules loaded by the bootloader
            //     },
            //     .reserved => {

            //     },
            //     // Handle other types as needed
            //     else => {},
            // }
        }
    } else {
        // No valid memory map received
        @panic("No memory map provided by Limine!");
    }

    // Output a test string to the serial port
    serial.write_string(serial.SERIAL_PORT_COM1, "DONE EVERYTHING - Cereal port!\n");

    // We're done, just hang...
    kernel.done();
}
