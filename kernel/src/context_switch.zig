const process = @import("process.zig");

pub fn switch_to(next_stack_pointer: usize) void {
    asm volatile (
        \\ mov eax, [esp + 4]
        \\ mov esp, eax
        \\ ret
        :
        : [next_stack_pointer] "{eax}" (next_stack_pointer),
        : "memory"
    );
}
