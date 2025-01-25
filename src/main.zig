const std = @import("std");
const c8 = struct {
    usingnamespace @import("types.zig");
    usingnamespace @import("registers.zig");
    usingnamespace @import("cpu.zig");
    usingnamespace @import("rom.zig");
};
const ray = @import("raylib.zig");

const stderr = std.io.getStdErr().writer();

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    // const stdout = std.io.getStdOut().writer();

    // Raylib init
    const pixel_size: i32 = 8;
    const screenwidth: i32 = 64 * pixel_size;
    const screenheight: i32 = 32 * pixel_size;
    const fps: u32 = 60;
    const target_freq: u32 = 60;

    ray.InitWindow(screenwidth, screenheight, "Chip-8 emulator");
    defer ray.CloseWindow();

    ray.SetTargetFPS(fps);

    // Chip8 init
    var program_name: []u8 = "";
    var program_bin: [0x1000]u8 = [_]u8{0} ** 0x1000;

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    // Get the program name
    for (args, 0..) |arg, i| {
        if (i == 0) continue;
        if (i == 1) {
            program_name = arg;
            break;
        }
    }

    if (std.mem.eql(u8, program_name, "")) {
        try stderr.print("Expected first argument to be a program name\nUsage: {s} <chip-8-program>\n", .{args[0]});
        return;
    }

    // Try to open the file
    const program_len = try c8.load_rom(program_name, &program_bin);

    var chip8: c8.Chip8 = .{};

    c8.set_rom(&chip8, &program_bin, program_len);

    // Timers must run at 60Hz, while CPU frequency is unspecified.
    var delay_thread = try std.Thread.spawn(.{}, c8.delayTimer, .{&chip8});
    var sound_thread = try std.Thread.spawn(.{}, c8.soundTimer, .{&chip8});
    // The threads should keep running indefinitely, let them stop when main exits
    delay_thread.detach();
    sound_thread.detach();

    // TODO
    // Initialize interpreter memory:
    //  - [x] load ROM
    //  - [ ] store sprites for 0x0-0xF in interpreter memory

    var time_acc: f32 = 0;
    while (!ray.WindowShouldClose()) {
        time_acc += ray.GetFrameTime();

        // Run instructions at the desired frequency
        while (time_acc > 1.0 / @as(f32, target_freq)) {
            time_acc -= 1.0 / @as(f32, target_freq);

            c8.runInstruction(&chip8);
            // std.debug.print("{x:0>4}\r", .{chip8.registers.PC});
        }

        // Drawing
        {
            ray.BeginDrawing();
            defer ray.EndDrawing();

            ray.ClearBackground(ray.DARKGRAY);

            for (chip8.screen, @as(i32, 0)..) |col, i| {
                for (0..@bitSizeOf(@TypeOf(col))) |row| {
                    if (col & (@as(u64, 1) << (@bitSizeOf(@TypeOf(col)) - 1 - @as(u6, @intCast(row)))) != 0) {
                        ray.DrawRectangle(@as(c_int, @intCast(row)) * pixel_size, @as(c_int, @intCast(i)) * pixel_size, pixel_size, pixel_size, ray.LIGHTGRAY);
                    }
                }
            }
        }
    }
}
