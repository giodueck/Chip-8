const std = @import("std");
const c8 = struct {
    usingnamespace @import("types.zig");
    usingnamespace @import("registers.zig");
    usingnamespace @import("cpu.zig");
    usingnamespace @import("rom.zig");
};
const ray = @import("raylib.zig");
const audio = @import("audio.zig");

const stderr = std.io.getStdErr().writer();

/// Print the display in binary to stderr
fn printDisplay(chip8: c8.Chip8) !void {
    for (0..c8.screen_height) |j| {
        try stderr.print("{b:0>64}\n", .{chip8.screen[j]});
    }
}

/// Run a single frame and however many instructions fit given the accumulated elapsed time t
/// Takes care of inputs and CPU cycles
/// Returns a new value for t
pub fn runFrame(chip8: *c8.Chip8, t: f32) f32 {
    var time_acc = t;

    // Inputs
    // Keypad
    chip8.keypad[0x0] = if (ray.IsKeyDown(@intFromEnum(c8.KeypadKey.K0))) true else false;
    chip8.keypad[0x1] = if (ray.IsKeyDown(@intFromEnum(c8.KeypadKey.K1))) true else false;
    chip8.keypad[0x2] = if (ray.IsKeyDown(@intFromEnum(c8.KeypadKey.K2))) true else false;
    chip8.keypad[0x3] = if (ray.IsKeyDown(@intFromEnum(c8.KeypadKey.K3))) true else false;
    chip8.keypad[0x4] = if (ray.IsKeyDown(@intFromEnum(c8.KeypadKey.K4))) true else false;
    chip8.keypad[0x5] = if (ray.IsKeyDown(@intFromEnum(c8.KeypadKey.K5))) true else false;
    chip8.keypad[0x6] = if (ray.IsKeyDown(@intFromEnum(c8.KeypadKey.K6))) true else false;
    chip8.keypad[0x7] = if (ray.IsKeyDown(@intFromEnum(c8.KeypadKey.K7))) true else false;
    chip8.keypad[0x8] = if (ray.IsKeyDown(@intFromEnum(c8.KeypadKey.K8))) true else false;
    chip8.keypad[0x9] = if (ray.IsKeyDown(@intFromEnum(c8.KeypadKey.K9))) true else false;
    chip8.keypad[0xA] = if (ray.IsKeyDown(@intFromEnum(c8.KeypadKey.KA))) true else false;
    chip8.keypad[0xB] = if (ray.IsKeyDown(@intFromEnum(c8.KeypadKey.KB))) true else false;
    chip8.keypad[0xC] = if (ray.IsKeyDown(@intFromEnum(c8.KeypadKey.KC))) true else false;
    chip8.keypad[0xD] = if (ray.IsKeyDown(@intFromEnum(c8.KeypadKey.KD))) true else false;
    chip8.keypad[0xE] = if (ray.IsKeyDown(@intFromEnum(c8.KeypadKey.KE))) true else false;
    chip8.keypad[0xF] = if (ray.IsKeyDown(@intFromEnum(c8.KeypadKey.KF))) true else false;

    // Run instructions at the desired frequency
    while (time_acc > 1.0 / @as(f32, @floatFromInt(chip8.freq))) {
        time_acc -= 1.0 / @as(f32, @floatFromInt(chip8.freq));

        c8.runInstruction(chip8) catch |interrupt| {
            switch (interrupt) {
                c8.Interrupt.Vblank => {
                    time_acc = 0;
                    continue;
                },
            }
        };
        // std.debug.print("{x:0>4}\r", .{@as(u16, chip8.memory[chip8.registers.PC]) << 8 | chip8.memory[chip8.registers.PC + 1]});
    }

    return time_acc;
}

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    // const stdout = std.io.getStdOut().writer();

    // Raylib init
    const pixel_size: i32 = 8;
    const screenwidth: i32 = 64 * pixel_size;
    const screenheight: i32 = 32 * pixel_size;
    const fps: u32 = 60;
    const target_freq: u32 = 1200;

    ray.InitWindow(screenwidth, screenheight, "Chip-8 emulator");
    defer ray.CloseWindow();

    const audio_stream = audio.initAudio();
    defer audio.deinitAudio(audio_stream);

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
    const program_len = try c8.loadRom(program_name, &program_bin);

    var chip8: c8.Chip8 = .{};
    chip8.freq = target_freq;

    c8.setRom(&chip8, &program_bin, program_len);

    // Timers must run at 60Hz, while CPU frequency is unspecified.
    var delay_thread = try std.Thread.spawn(.{}, c8.delayTimer, .{&chip8});
    var sound_thread = try std.Thread.spawn(.{}, c8.soundTimer, .{ &chip8, audio_stream });
    // The threads should keep running indefinitely, let them stop when main exits
    delay_thread.detach();
    sound_thread.detach();

    var time_acc: f32 = 0;
    while (!ray.WindowShouldClose()) {
        time_acc += ray.GetFrameTime();

        // Input and CPU cycles
        time_acc = runFrame(&chip8, time_acc);

        // Debug
        if (ray.IsKeyPressed(ray.KEY_P)) {
            try printDisplay(chip8);
        }

        // Drawing
        {
            ray.BeginDrawing();
            defer ray.EndDrawing();

            ray.ClearBackground(ray.DARKGRAY);

            for (chip8.screen, 0..32) |row, i| {
                for (0..64) |col| {
                    if (row & (@as(u64, 1) << (@bitSizeOf(@TypeOf(row)) - 1 - @as(u6, @intCast(col)))) != 0) {
                        ray.DrawRectangle(@as(c_int, @intCast(col)) * pixel_size, @as(c_int, @intCast(i)) * pixel_size, pixel_size, pixel_size, ray.LIGHTGRAY);
                    }
                }
            }
        }
    }
}
