const std = @import("std");
const c8 = struct {
    usingnamespace @import("types.zig");
    usingnamespace @import("registers.zig");
};

// TODO
//  - store sprites for 0x0-0xF in interpreter memory

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("Hello world\n", .{});

    var chip8: c8.Chip8 = .{};

    // Timers must run at 60Hz, while CPU frequency is unspecified.
    var delay_thread = try std.Thread.spawn(.{}, c8.delayTimer, .{&chip8});
    var sound_thread = try std.Thread.spawn(.{}, c8.soundTimer, .{&chip8});
    // The threads should keep running indefinitely, let them stop when main exits
    delay_thread.detach();
    sound_thread.detach();

    chip8.delay_mutex.lock();
    chip8.registers.DT = 60;
    chip8.delay_mutex.unlock();

    while (chip8.registers.DT > 0) {
        std.time.sleep(std.time.ns_per_s / 15);
    }
}
