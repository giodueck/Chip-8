const std = @import("std");
const c8 = struct {
    usingnamespace @import("types.zig");
};
const ray = @import("raylib.zig");
const audio = @import("audio.zig");

/// This function is meant to run as a thread, decrementing the delay register at 60Hz unless it is 0.
/// It does this while locking a mutex to avoid race conditions, but in a non-blocking manner.
pub fn delayTimer(chip8: *c8.Chip8) void {
    var dec: u8 = 1;
    while (true) {
        std.time.sleep(std.time.ns_per_s / 60);

        // Avoid waiting for lock, instead just decrement by one more if the lock can't be acquired
        if (chip8.delay_mutex.tryLock()) {
            defer chip8.delay_mutex.unlock();
            if (chip8.registers.DT > 0) {
                if (dec > chip8.registers.DT) {
                    chip8.registers.DT = 0;
                } else {
                    chip8.registers.DT -= dec;
                }
            }
            dec = 1;
        } else {
            dec += 1;
        }
    }
}

/// This function is meant to run as a thread, decrementing the sound register at 60Hz and playing a sound unless it is 0.
/// It does this while locking a mutex to avoid race conditions, but in a non-blocking manner.
pub fn soundTimer(chip8: *c8.Chip8, stream: ray.AudioStream) void {
    var dec: u8 = 1;
    while (true) {
        std.time.sleep(std.time.ns_per_s / 60);

        // Avoid waiting for lock, instead just decrement by one more if the lock can't be acquired
        if (chip8.sound_mutex.tryLock()) {
            defer chip8.sound_mutex.unlock();
            if (chip8.registers.ST > 0) {
                audio.playAudio(stream);
                if (dec > chip8.registers.ST) {
                    chip8.registers.ST = 0;
                } else {
                    chip8.registers.ST -= dec;
                }
            } else {
                audio.pauseAudio(stream);
            }
            dec = 1;
        } else {
            dec += 1;
        }
    }
}
