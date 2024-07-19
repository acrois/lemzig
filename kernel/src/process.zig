const std = @import("std");
const serial = @import("serial.zig");
const memory = @import("memory.zig");

// Define a simple process control block (PCB)
const Process = struct {
    id: u32,
    stack: [*]u8,
    stack_size: usize,
    stack_pointer: usize,
    instruction_pointer: usize,
    registers: Registers,
    state: enum { Ready, Running, Terminated },
};

const Registers = struct {
    rax: u64,
    rbx: u64,
    rcx: u64,
    rdx: u64,
    rsi: u64,
    rdi: u64,
    rbp: u64,
    r8: u64,
    r9: u64,
    r10: u64,
    r11: u64,
    r12: u64,
    r13: u64,
    r14: u64,
    r15: u64,
    rflags: u64,
};

// Define our scheduler
const Scheduler = struct {
    processes: [10]?Process, // Support up to 10 processes
    current_process: usize,
    time_slice: u64, // in milliseconds

    pub fn init() Scheduler {
        return Scheduler{
            .processes = [_]?Process{null} ** 10,
            .current_process = 0,
            .time_slice = 100, // 100ms time slice
        };
    }

    pub fn create_process(self: *Scheduler, program: [*]u8, size: usize) ?u32 {
        const stack_size = 4096; // 4KB stack
        const stack = memory.kernel_allocator.alloc(stack_size) orelse return error.OutOfMemory;

        var process_id: u32 = 0;
        while (process_id < self.processes.len) : (process_id += 1) {
            if (self.processes[process_id] == null) {
                self.processes[process_id] = Process{
                    .id = process_id,
                    .stack = stack,
                    .stack_size = stack_size,
                    .stack_pointer = @intFromPtr(stack) + stack_size, // Start at top of stack
                    .instruction_pointer = @intFromPtr(program),
                    .registers = std.mem.zeroes(Registers),
                    .state = .Ready,
                };
                // Set up initial stack frame
                const process = &self.processes[process_id].?;
                process.stack_pointer -= @sizeOf(u64);
                @as(*u64, @ptrFromInt(process.stack_pointer)).* = 0; // Return address (unused)
                process.registers.rflags = 0x202; // Enable interrupts
                @memcpy(program[0..size], process.stack[0..size]);
                return process_id;
            }
        }

        return error.MaxProcessesReached;
    }
    // pub fn create_process(self: *Scheduler, program: [*]u8, size: usize) !u32 {
    //     const stack_size = 4096; // 4KB stack
    //     const stack = memory.kernel_allocator.alloc(stack_size) orelse return error.OutOfMemory;

    //     var process_id: u32 = 0;
    //     while (process_id < self.processes.len) : (process_id += 1) {
    //         if (self.processes[process_id] == null) {
    //             self.processes[process_id] = Process{
    //                 .id = process_id,
    //                 .stack = stack,
    //                 .stack_size = stack_size,
    //                 .instruction_pointer = @intFromPtr(program),
    //                 .registers = [_]u64{0} ** 16,
    //                 .state = .Ready,
    //             };
    //             return process_id;
    //         }
    //     }

    //     return error.MaxProcessesReached;
    // }

    pub fn schedule(self: *Scheduler) void {
        // Simple round-robin scheduling
        var next_process = (self.current_process + 1) % self.processes.len;

        while (next_process != self.current_process) {
            if (self.processes[next_process]) |*process| {
                if (process.state == .Ready) {
                    self.switch_to(next_process);
                    return;
                }
            }
            next_process = (next_process + 1) % self.processes.len;
        }
    }

    fn switch_to(self: *Scheduler, process_id: usize) void {
        if (self.processes[self.current_process]) |*current| {
            if (current.state == .Running) {
                current.state = .Ready;
                current.save_context(current);
            }
        }

        self.current_process = process_id;
        if (self.processes[process_id]) |*next| {
            next.state = .Running;
            next.restore_context(next);
        }
    }

    fn save_context(process: *Process) void {
        asm volatile (
            \\movq %%rax, %[rax]
            \\movq %%rbx, %[rbx]
            \\movq %%rcx, %[rcx]
            \\movq %%rdx, %[rdx]
            \\movq %%rsi, %[rsi]
            \\movq %%rdi, %[rdi]
            \\movq %%rbp, %[rbp]
            \\movq %%r8,  %[r8]
            \\movq %%r9,  %[r9]
            \\movq %%r10, %[r10]
            \\movq %%r11, %[r11]
            \\movq %%r12, %[r12]
            \\movq %%r13, %[r13]
            \\movq %%r14, %[r14]
            \\movq %%r15, %[r15]
            \\pushfq
            \\popq %[rflags]
            \\movq %%rsp, %[stack_pointer]
            \\leaq (%%rip), %[instruction_pointer]
            :
            : [rax] "=m" (process.registers.rax),
              [rbx] "=m" (process.registers.rbx),
              [rcx] "=m" (process.registers.rcx),
              [rdx] "=m" (process.registers.rdx),
              [rsi] "=m" (process.registers.rsi),
              [rdi] "=m" (process.registers.rdi),
              [rbp] "=m" (process.registers.rbp),
              [r8] "=m" (process.registers.r8),
              [r9] "=m" (process.registers.r9),
              [r10] "=m" (process.registers.r10),
              [r11] "=m" (process.registers.r11),
              [r12] "=m" (process.registers.r12),
              [r13] "=m" (process.registers.r13),
              [r14] "=m" (process.registers.r14),
              [r15] "=m" (process.registers.r15),
              [rflags] "=m" (process.registers.rflags),
              [stack_pointer] "=m" (process.stack_pointer),
              [instruction_pointer] "=m" (process.instruction_pointer),
            : "memory"
        );
    }

    fn restore_context(process: *Process) void {
        asm volatile (
            \\movq %[rax], %%rax
            \\movq %[rbx], %%rbx
            \\movq %[rcx], %%rcx
            \\movq %[rdx], %%rdx
            \\movq %[rsi], %%rsi
            \\movq %[rdi], %%rdi
            \\movq %[rbp], %%rbp
            \\movq %[r8],  %%r8
            \\movq %[r9],  %%r9
            \\movq %[r10], %%r10
            \\movq %[r11], %%r11
            \\movq %[r12], %%r12
            \\movq %[r13], %%r13
            \\movq %[r14], %%r14
            \\movq %[r15], %%r15
            \\pushq %[rflags]
            \\popfq
            \\movq %[stack_pointer], %%rsp
            \\jmp *%[instruction_pointer]
            :
            : [rax] "m" (process.registers.rax),
              [rbx] "m" (process.registers.rbx),
              [rcx] "m" (process.registers.rcx),
              [rdx] "m" (process.registers.rdx),
              [rsi] "m" (process.registers.rsi),
              [rdi] "m" (process.registers.rdi),
              [rbp] "m" (process.registers.rbp),
              [r8] "m" (process.registers.r8),
              [r9] "m" (process.registers.r9),
              [r10] "m" (process.registers.r10),
              [r11] "m" (process.registers.r11),
              [r12] "m" (process.registers.r12),
              [r13] "m" (process.registers.r13),
              [r14] "m" (process.registers.r14),
              [r15] "m" (process.registers.r15),
              [rflags] "m" (process.registers.rflags),
              [stack_pointer] "m" (process.stack_pointer),
              [instruction_pointer] "m" (process.instruction_pointer),
            : "memory"
        );
    }

    // fn switch_to(self: *Scheduler, process_id: usize) void {
    //     if (self.processes[self.current_process]) |*current| {
    //         if (current.state == .Running) {
    //             current.state = .Ready;
    //         }
    //     }

    //     self.current_process = process_id;
    //     if (self.processes[process_id]) |*next| {
    //         next.state = .Running;
    //         // Here we would actually switch context to the new process
    //         // This would involve saving the current CPU state and loading the new one
    //         // For demonstration, we'll just print a message
    //         var buffer: [100]u8 = undefined;
    //         const info = std.fmt.bufPrint(&buffer, "Switching to process {}\n", .{next.id}) catch "Error formatting process info";
    //         serial.write_string(serial.SERIAL_PORT_COM1, info);
    //     }
    // }
};

const IDTEntry = packed struct {
    offset_low: u16,
    segment_selector: u16,
    ist: u8,
    type_attr: u8,
    offset_mid: u16,
    offset_high: u32,
    reserved: u32,
};

const InterruptFrame = packed struct {
    rip: u64,
    cs: u64,
    rflags: u64,
    rsp: u64,
    ss: u64,
};

const IDTR = packed struct {
    limit: u16,
    base: u64,
};

const IDT_ENTRIES: usize = 256;
var idt: [IDT_ENTRIES]IDTEntry = undefined;
var idtr: IDTR = undefined;
const InterruptHandler = *const fn (interrupt_frame: *InterruptFrame) void;
var interrupt_handlers: [IDT_ENTRIES]?InterruptHandler = [_]?InterruptHandler{null} ** IDT_ENTRIES;

var scheduler: Scheduler = undefined;

pub fn init_scheduler() void {
    scheduler = Scheduler.init();
    init_interrupts();
}

pub fn create_user_process(program: [*]u8, size: usize) ?u32 {
    return scheduler.create_process(program, size);
}

// pub fn run_scheduler() void {
//     while (true) {
//         scheduler.schedule();
//         // In a real system, we'd set up a timer interrupt to call this function
//         // periodically. For now, we'll just add a small delay.
//         delay(scheduler.time_slice);
//     }
// }

pub fn init_interrupts() void {
    setup_idt();
    interrupt_handlers[0x20] = timer_interrupt_handler;
    interrupt_handlers[0x21] = keyboard_interrupt_handler;
    init_pic();
}

fn init_pic() void {
    // Remap PIC
    asm volatile (
        \\movb $0x11, %%al
        \\outb %%al, $0x20
        \\outb %%al, $0xA0
        \\movb $0x20, %%al
        \\outb %%al, $0x21
        \\movb $0x28, %%al
        \\outb %%al, $0xA1
        \\movb $0x04, %%al
        \\outb %%al, $0x21
        \\movb $0x02, %%al
        \\outb %%al, $0xA1
        \\movb $0x01, %%al
        \\outb %%al, $0x21
        \\outb %%al, $0xA1
        \\movb $0xFC, %%al
        \\outb %%al, $0x21
        \\movb $0xFF, %%al
        \\outb %%al, $0xA1
        ::: "al");
}

pub fn run_scheduler() void {
    // Set up timer interrupt
    init_timer(scheduler.time_slice);

    // Enable interrupts
    asm volatile ("sti");

    // Start first process
    if (scheduler.processes[0]) |*first_process| {
        first_process.state = .Running;
        first_process.restore_context(first_process);
    }

    // Should never reach here
    @panic("No processes to run");
}

fn init_timer(time_slice_ms: u64) void {
    // Set up PIT (Programmable Interval Timer)
    const frequency: u32 = 1000 / time_slice_ms;
    const divisor: u16 = @intCast(1193180 / frequency);

    asm volatile (
        \\cli
        \\movb $0x36, %%al
        \\outb %%al, $0x43
        \\movw %[divisor], %%ax
        \\outb %%al, $0x40
        \\movb %%ah, %%al
        \\outb %%al, $0x40
        :
        : [divisor] "r" (divisor),
        : "al", "ax"
    );

    // Set up timer interrupt handler
    // This part depends on how you've set up your Interrupt Descriptor Table (IDT)
    // For example:
    // set_interrupt_handler(0x20, timer_interrupt_handler);

    // Remap PIC
    // asm volatile (
    //     \\movb $0x11, %%al
    //     \\outb %%al, $0x20
    //     \\outb %%al, $0xA0
    //     \\movb $0x20, %%al
    //     \\outb %%al, $0x21
    //     \\movb $0x28, %%al
    //     \\outb %%al, $0xA1
    //     \\movb $0x04, %%al
    //     \\outb %%al, $0x21
    //     \\movb $0x02, %%al
    //     \\outb %%al, $0xA1
    //     \\movb $0x01, %%al
    //     \\outb %%al, $0x21
    //     \\outb %%al, $0xA1
    //     \\movb $0xFC, %%al
    //     \\outb %%al, $0x21
    //     \\movb $0xFF, %%al
    //     \\outb %%al, $0xA1
    //     ::: "al");
}

fn timer_interrupt_handler(_: *InterruptFrame) void {
    // Save context of current process
    if (scheduler.processes[scheduler.current_process]) |*current| {
        current.save_context(current);
    }

    // Schedule next process
    scheduler.schedule();

    // Send EOI (End of Interrupt) to PIC
    // outb(0x20, 0x20);
    // asm volatile ("outb %%al, $0x20" :: "a" (0x20));
}

// Keyboard interrupt handler
fn keyboard_interrupt_handler(_: *InterruptFrame) void {
    const keyboard_data_port: u16 = 0x60;
    const keyboard_status_port: u16 = 0x64;

    var status: u8 = undefined;
    var scancode: u8 = undefined;

    asm volatile (
        \\inb %[status_port], %[status]
        \\testb $0x01, %[status]
        \\jz 1f
        \\inb %[data_port], %[scancode]
        \\1:
        : [status] "=a" (status),
          [scancode] "=b" (scancode),
        : [status_port] "N" (keyboard_status_port),
          [data_port] "N" (keyboard_data_port),
    );

    if ((status & 1) != 0) {
        handle_keyboard_input(scancode);
    }
}

fn handle_keyboard_input(scancode: u8) void {
    // Simple scancode to ASCII conversion (for US QWERTY keyboard)
    const scancodes = "??1234567890-=??qwertyuiop[]??asdfghjkl;'`?\\zxcvbnm,./???";
    if (scancode < scancodes.len) {
        const c = scancodes[scancode];
        if (c != '?') {
            var buffer: [2]u8 = undefined;
            buffer[0] = c;
            buffer[1] = '\n';
            serial.write_string(serial.SERIAL_PORT_COM1, &buffer);
        }
    }
}

inline fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "N{dx}" (port),
    );
}

fn delay(milliseconds: u64) void {
    // This is a very naive delay function. In a real system, you'd use a hardware timer.
    var i: u64 = 0;
    while (i < milliseconds * 10000) : (i += 1) {
        asm volatile ("nop");
    }
}

fn setup_idt() void {
    // Clear the IDT
    @memset(&idt, std.mem.zeroes(IDTEntry));

    // Set up the IDTR
    idtr = IDTR{
        .limit = @sizeOf(@TypeOf(idt)) - 1,
        .base = @intFromPtr(&idt),
    };

    // Set up individual interrupt handlers
    set_idt_entry(0x20, wrapped_timer_interrupt_handler, 0x08, 0x8E); // Timer interrupt
    set_idt_entry(0x21, wrapped_keyboard_interrupt_handler, 0x08, 0x8E); // Keyboard interrupt

    // Load the IDT
    asm volatile ("lidt (%[idtr])"
        :
        : [idtr] "r" (&idtr),
    );
}

fn set_idt_entry(index: u8, handler: fn () callconv(.Interrupt) void, segment_selector: u16, type_attr: u8) void {
    const addr = @intFromPtr(handler);
    idt[index] = IDTEntry{
        .offset_low = @truncate(addr),
        .segment_selector = segment_selector,
        .ist = 0,
        .type_attr = type_attr,
        .offset_mid = @truncate(addr >> 16),
        .offset_high = @truncate(addr >> 32),
        .reserved = 0,
    };
}

fn send_eoi(irq: u8) void {
    if (irq >= 8) {
        // Send EOI to slave PIC
        asm volatile ("outb %[cmd], $0xA0"
            :
            : [cmd] "a" (0x20),
        );
    }
    // Send EOI to master PIC
    asm volatile ("outb %[cmd], $0x20"
        :
        : [cmd] "a" (0x20),
    );
}

// Wrapper functions for our interrupt handlers
fn wrapped_timer_interrupt_handler() callconv(.Interrupt) void {
    if (interrupt_handlers[0x20]) |handler| {
        var frame: InterruptFrame = undefined;
        asm volatile ("mov %%rsp, %[frame]"
            :
            : [frame] "=r" (&frame),
        );
        handler(&frame);
    }
    send_eoi(0x20);
}

fn wrapped_keyboard_interrupt_handler() callconv(.Interrupt) void {
    if (interrupt_handlers[0x21]) |handler| {
        var frame: InterruptFrame = undefined;
        asm volatile ("mov %%rsp, %[frame]"
            :
            : [frame] "=r" (&frame),
        );
        handler(&frame);
    }
    send_eoi(0x21);
}
