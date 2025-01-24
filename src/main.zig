const std = @import("std");
const c8 = struct {
    usingnamespace @import("types.zig");
    usingnamespace @import("registers.zig");
    usingnamespace @import("cpu.zig");
    usingnamespace @import("rom.zig");
};

const stderr = std.io.getStdErr().writer();

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    // const stdout = std.io.getStdOut().writer();

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

    // For debugging: output program binary
    // for (program_bin[0x200..(0x200 + program_len)], 0..) |b, i| {
    //     if (i % 16 == 0 and i != 0) {
    //         try stderr.writeAll("\n");
    //     } else if (i % 2 == 0 and i != 0) {
    //         try stderr.writeAll(" ");
    //     }
    //     try stderr.print("{x:0^2}", .{b});
    // }
    // try stderr.writeAll("\n");

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
    //  - store sprites for 0x0-0xF in interpreter memory

    for (0..50) |i| {
        try stderr.print("{d}: PC = {x:0^3} => {x:0>2}{x:0>2}; Reg: {}\n", .{ i, chip8.registers.PC, chip8.memory[chip8.registers.PC], chip8.memory[chip8.registers.PC + 1], chip8.registers });
        c8.runInstruction(&chip8);

        // print display
        for (0..c8.screen_height) |j| {
            try stderr.print("{b:0>64}\n", .{chip8.screen[j]});
        }
    }
}
