const std = @import("std");
const c8 = struct {
    usingnamespace @import("types.zig");
    usingnamespace @import("registers.zig");
};

// TODO
//  - store sprites for 0x0-0xF in interpreter memory

pub fn main() !void {
    // const stdout = std.io.getStdOut().writer();

    var chip8: c8.Chip8 = .{};

    // Timers must run at 60Hz, while CPU frequency is unspecified.
    var delay_thread = try std.Thread.spawn(.{}, c8.delayTimer, .{&chip8});
    var sound_thread = try std.Thread.spawn(.{}, c8.soundTimer, .{&chip8});
    // The threads should keep running indefinitely, let them stop when main exits
    delay_thread.detach();
    sound_thread.detach();

    // Entry point for most Chip-8 programs
    chip8.registers.PC = 0x200;
}
