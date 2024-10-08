const std = @import("std");
const limine = @import("limine");
const kernel = @import("kernel.zig");
const serial = @import("serial.zig");

fn blend(s: u32, f: u32, t: f32) u32 {
    const r: u32 = @intFromFloat(@as(f32, @floatFromInt((s >> 16) & 0xFF)) * (1 - t) + @as(f32, @floatFromInt((f >> 16) & 0xFF)) * t);
    const g: u32 = @intFromFloat(@as(f32, @floatFromInt((s >> 8) & 0xFF)) * (1 - t) + @as(f32, @floatFromInt((f >> 8) & 0xFF)) * t);
    const b: u32 = @intFromFloat(@as(f32, @floatFromInt(s & 0xFF)) * (1 - t) + @as(f32, @floatFromInt(f & 0xFF)) * t);
    return (r << 16) | (g << 8) | b;
}

fn drawPixel(framebuffer: *limine.Framebuffer, x: usize, y: usize, color: u32) void {
    const pixel_offset = y * framebuffer.pitch + x * 4;
    @as(*u32, @ptrCast(@alignCast(framebuffer.address + pixel_offset))).* = color;
}

fn drawChar(framebuffer: *limine.Framebuffer, x: usize, y: usize, c: u8, color: u32) void {
    const font = [_]u64{
        0x0000000000000000, // U+0000 (nul)
        0x0000000000000000, // U+0001
        0x0000000000000000, // U+0002
        0x0000000000000000, // U+0003
        0x0000000000000000, // U+0004
        0x0000000000000000, // U+0005
        0x0000000000000000, // U+0006
        0x0000000000000000, // U+0007
        0x0000000000000000, // U+0008
        0x0000000000000000, // U+0009
        0x0000000000000000, // U+000A
        0x0000000000000000, // U+000B
        0x0000000000000000, // U+000C
        0x0000000000000000, // U+000D
        0x0000000000000000, // U+000E
        0x0000000000000000, // U+000F
        0x0000000000000000, // U+0010
        0x0000000000000000, // U+0011
        0x0000000000000000, // U+0012
        0x0000000000000000, // U+0013
        0x0000000000000000, // U+0014
        0x0000000000000000, // U+0015
        0x0000000000000000, // U+0016
        0x0000000000000000, // U+0017
        0x0000000000000000, // U+0018
        0x0000000000000000, // U+0019
        0x0000000000000000, // U+001A
        0x0000000000000000, // U+001B
        0x0000000000000000, // U+001C
        0x0000000000000000, // U+001D
        0x0000000000000000, // U+001E
        0x0000000000000000, // U+001F
        0x0000000000000000, // U+0020 (space)
        0x183C3C1818001800, // U+0021 (!)
        0x3636000000000000, // U+0022 (")
        0x36367F367F363600, // U+0023 (#)
        0x0C3E031E301F0C00, // U+0024 ($)
        0x006333180C666300, // U+0025 (%)
        0x1C361C6E3B336E00, // U+0026 (&)
        0x0606030000000000, // U+0027 (')
        0x180C0606060C1800, // U+0028 (()
        0x060C1818180C0600, // U+0029 ())
        0x00663CFF3C660000, // U+002A (*)
        0x000C0C3F0C0C0000, // U+002B (+)
        0x00000000000C0C06, // U+002C (,)
        0x0000003F00000000, // U+002D (-)
        0x00000000000C0C00, // U+002E (.)
        0x6030180C06030100, // U+002F (/)
        0x3E63737B6F673E00, // U+0030 (0)
        0x0C0E0C0C0C0C3F00, // U+0031 (1)
        0x1E33301C06333F00, // U+0032 (2)
        0x1E33301C30331E00, // U+0033 (3)
        0x383C36337F307800, // U+0034 (4)
        0x3F031F3030331E00, // U+0035 (5)
        0x1C06031F33331E00, // U+0036 (6)
        0x3F3330180C0C0C00, // U+0037 (7)
        0x1E33331E33331E00, // U+0038 (8)
        0x1E33333E30180E00, // U+0039 (9)
        0x000C0C00000C0C00, // U+003A (:)
        0x000C0C00000C0C06, // U+003B (;)
        0x180C0603060C1800, // U+003C (<)
        0x00003F00003F0000, // U+003D (=)
        0x060C1830180C0600, // U+003E (>)
        0x1E3330180C000C00, // U+003F (?)
        0x3E637B7B7B031E00, // U+0040 (@)
        0x0C1E33333F333300, // U+0041 (A)
        0x3F66663E66663F00, // U+0042 (B)
        0x3C66030303663C00, // U+0043 (C)
        0x1F36666666361F00, // U+0044 (D)
        0x7F46161E16467F00, // U+0045 (E)
        0x7F46161E16060F00, // U+0046 (F)
        0x3C66030373667C00, // U+0047 (G)
        0x3333333F33333300, // U+0048 (H)
        0x1E0C0C0C0C0C1E00, // U+0049 (I)
        0x7830303033331E00, // U+004A (J)
        0x6766361E36666700, // U+004B (K)
        0x0F06060646667F00, // U+004C (L)
        0x63777F7F6B636300, // U+004D (M)
        0x63676F7B73636300, // U+004E (N)
        0x1C36636363361C00, // U+004F (O)
        0x3F66663E06060F00, // U+0050 (P)
        0x1E3333333B1E3800, // U+0051 (Q)
        0x3F66663E36666700, // U+0052 (R)
        0x1E33070E38331E00, // U+0053 (S)
        0x3F2D0C0C0C0C1E00, // U+0054 (T)
        0x3333333333333F00, // U+0055 (U)
        0x33333333331E0C00, // U+0056 (V)
        0x6363636B7F776300, // U+0057 (W)
        0x6363361C1C366300, // U+0058 (X)
        0x3333331E0C0C1E00, // U+0059 (Y)
        0x7F6331184C667F00, // U+005A (Z)
        0x1E06060606061E00, // U+005B ([)
        0x03060C1830604000, // U+005C (\)
        0x1E18181818181E00, // U+005D (])
        0x081C366300000000, // U+005E (^)
        0x00000000000000FF, // U+005F (_)
        0x0C0C180000000000, // U+0060 (`)
        0x00001E303E336E00, // U+0061 (a)
        0x0706063E66663B00, // U+0062 (b)
        0x00001E3303331E00, // U+0063 (c)
        0x3830303e33336E00, // U+0064 (d)
        0x00001E333f031E00, // U+0065 (e)
        0x1C36060f06060F00, // U+0066 (f)
        0x00006E33333E301F, // U+0067 (g)
        0x0706366E66666700, // U+0068 (h)
        0x0C000E0C0C0C1E00, // U+0069 (i)
        0x300030303033331E, // U+006A (j)
        0x070666361E366700, // U+006B (k)
        0x0E0C0C0C0C0C1E00, // U+006C (l)
        0x0000337F7F6B6300, // U+006D (m)
        0x00001F3333333300, // U+006E (n)
        0x00001E3333331E00, // U+006F (o)
        0x00003B66663E060F, // U+0070 (p)
        0x00006E33333E3078, // U+0071 (q)
        0x00003B6E66060F00, // U+0072 (r)
        0x00003E031E301F00, // U+0073 (s)
        0x080C3E0C0C2C1800, // U+0074 (t)
        0x0000333333336E00, // U+0075 (u)
        0x00003333331E0C00, // U+0076 (v)
        0x0000636B7F7F3600, // U+0077 (w)
        0x000063361C366300, // U+0078 (x)
        0x00003333333E301F, // U+0079 (y)
        0x00003F190C263F00, // U+007A (z)
        0x380C0C070C0C3800, // U+007B ({)
        0x1818180018181800, // U+007C (|)
        0x070C0C380C0C0700, // U+007D (})
        0x6E3B000000000000, // U+007E (~)
        0x0000000000000000, // U+007F
    };

    // const char_index = if (c >= ' ' and c <= '~') c - ' ' else 0;
    const char_data = font[c];

    for (0..8) |dy| {
        for (0..8) |dx| {
            if ((char_data >> @intCast(dy * 8 + (7 - dx))) & 1 == 1) {
                drawPixel(framebuffer, x - dx, y - dy, color);
            }
        }
    }
}

pub fn draw(framebuffer_response: *limine.FramebufferResponse) void {
    if (framebuffer_response.framebuffer_count < 1) {
        kernel.done();
    }

    var buffer: [20]u8 = undefined;
    const cstr = std.fmt.bufPrint(&buffer, "Framebuffers: {}\n", .{framebuffer_response.framebuffer_count}) catch "Error";
    serial.write_string(serial.SERIAL_PORT_COM1, cstr);

    const framebuffer = framebuffer_response.framebuffers()[0];

    // Draw gradient background
    const top_color: u32 = 0x87CEEB; // Sky blue
    const bottom_color: u32 = 0x4682B4; // Steel blue

    for (0..framebuffer.height) |y| {
        const t: f32 = @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(framebuffer.height - 1));
        const color = blend(top_color, bottom_color, t);

        for (0..framebuffer.width) |x| {
            drawPixel(framebuffer, x, y, color);
        }
    }

    // Draw text
    const text = "Hello, Zig OS!";
    const text_color: u32 = 0x0; // White
    const text_x = 10;
    const text_y = 10;

    for (text, 0..) |c, i| {
        drawChar(framebuffer, text_x + i * 6, text_y, c, text_color);
    }
}
