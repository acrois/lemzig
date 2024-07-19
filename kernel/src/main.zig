const kernel = @import("kernel.zig");
const serial = @import("serial.zig");
const framebuffer = @import("framebuffer.zig");
const security = @import("security.zig");
const limine = @import("limine");
const std = @import("std");
const memory = @import("memory.zig");
const process = @import("process.zig");

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
        const estimated_freq = kernel.estimate_cpu_frequency() / 1_000_000;
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

    memory.init_memory();
    process.init_scheduler();

    // Create some test programs
    const program1_size = 1024;
    const program2_size = 2048;

    if (memory.alloc_user_space_program(program1_size)) |program1_memory| {
        if (process.create_user_process(program1_memory, program1_size)) |process_id| {
            var buffer: [100]u8 = undefined;
            const info = std.fmt.bufPrint(&buffer, "Created process {} for program 1\n", .{process_id}) catch "Error formatting process info";
            serial.write_string(serial.SERIAL_PORT_COM1, info);
        } else {
            serial.write_string(serial.SERIAL_PORT_COM1, "Failed to create process for program 1\n");
        }
    } else {
        serial.write_string(serial.SERIAL_PORT_COM1, "Failed to allocate memory for program 1\n");
    }

    if (memory.alloc_user_space_program(program2_size)) |program2_memory| {
        if (process.create_user_process(program2_memory, program2_size)) |process_id| {
            var buffer: [100]u8 = undefined;
            const info = std.fmt.bufPrint(&buffer, "Created process {} for program 2\n", .{process_id}) catch "Error formatting process info";
            serial.write_string(serial.SERIAL_PORT_COM1, info);
        } else {
            serial.write_string(serial.SERIAL_PORT_COM1, "Failed to create process for program 2\n");
        }
    } else {
        serial.write_string(serial.SERIAL_PORT_COM1, "Failed to allocate memory for program 2\n");
    }

    // Print the memory map for debugging
    memory.kernel_allocator.print_memory_map();
    process.run_scheduler();

    // Output a test string to the serial port
    serial.write_string(serial.SERIAL_PORT_COM1, "DONE EVERYTHING - Cereal port!\n");

    // We're done, just hang...
    kernel.done();
}
