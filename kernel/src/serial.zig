// Serial port addresses
pub const SERIAL_PORT_COM1 = 0x3F8;
pub const SERIAL_PORT_COM2 = 0x2F8;
pub const SERIAL_PORT_COM3 = 0x3E8;
pub const SERIAL_PORT_COM4 = 0x2E8;
pub const SERIAL_PORT_COM5 = 0x5F8;
pub const SERIAL_PORT_COM6 = 0x4F8;
pub const SERIAL_PORT_COM7 = 0x5E8;
pub const SERIAL_PORT_COM8 = 0x4E8;

inline fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "N{dx}" (port),
    );
}

inline fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "N{dx}" (port),
    );
}

// Initialize the serial port
pub fn init(port: u16) void {
    outb(port + 1, 0x00); // Disable all interrupts
    outb(port + 3, 0x80); // Enable DLAB (set baud rate divisor)
    outb(port + 0, 0x03); // Set divisor to 3 (lo byte) 38400 baud
    outb(port + 1, 0x00); //                  (hi byte)
    outb(port + 3, 0x03); // 8 bits, no parity, one stop bit
    outb(port + 2, 0xC7); // Enable FIFO, clear them, with 14-byte threshold
    outb(port + 4, 0x0B); // IRQs enabled, RTS/DSR set
}

// Check if the serial port is ready to transmit
fn is_transmit_empty(port: u16) bool {
    return (inb(port + 5) & 0x20) != 0;
}

// Write a character to the serial port
pub fn write_char(port: u16, c: u8) void {
    while (!is_transmit_empty(port)) {}
    outb(port, c);
}

// Write a string to the serial port
pub fn write_string(port: u16, s: []const u8) void {
    for (s) |c| {
        if (c == '\n') {
            write_char(port, '\r');
        }
        write_char(port, c);
    }
}
