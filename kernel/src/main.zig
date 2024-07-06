const limine = @import("limine");
const kernel = @import("kernel.zig");
const serial = @import("serial.zig");
const framebuffer = @import("framebuffer.zig");
const process = @import("process.zig");
const security = @import("security.zig");

export fn _start() callconv(.C) noreturn {
    kernel.init();
    serial.init(serial.SERIAL_PORT_COM1);
    security.init();
    process.init();

    // Output a test string to the serial port
    serial.write_string(serial.SERIAL_PORT_COM1, "Hello, Serial World!\n");

    // Ensure we got a framebuffer.
    if (kernel.framebuffer_request.response) |framebuffer_response| {
        framebuffer.draw(framebuffer_response);
    }

    // Output a test string to the serial port
    serial.write_string(serial.SERIAL_PORT_COM1, "Cereal port!\n");

    const p = process.create_process(main);
    serial.write_string(serial.SERIAL_PORT_COM1, p.id);
    process.schedule();

    // We're done, just hang...
    kernel.done();
}

fn main() void {
    // Main kernel code
    while (true) {
        // Simulate some work
    }
}
