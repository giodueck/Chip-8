const std = @import("std");

const register_count = 16;
const memory_size = 0x1000;
const memory_start = 0x200;
const memory_start_eti660 = 0x600;
const screen_width = 64;
const screen_height = 32;
const screen_width_2 = 128;
const screen_height_2 = 64;
const sprite_max_size = 15; // bytes, that is 8x15 bits

const RegisterMap = struct {
    V0: u8 = 0,
    V1: u8 = 0,
    V2: u8 = 0,
    V3: u8 = 0,
    V4: u8 = 0,
    V5: u8 = 0,
    V6: u8 = 0,
    V7: u8 = 0,
    V8: u8 = 0,
    V9: u8 = 0,
    VA: u8 = 0,
    VB: u8 = 0,
    VC: u8 = 0,
    VD: u8 = 0,
    VE: u8 = 0,
    VF: u8 = 0, // flag register
    I: u16 = 0, // memory address register, typically only lower 12 bits used
    DT: u8 = 0, // delay timer register: counts down at 60Hz, deactivates at 0
    ST: u8 = 0, // sound timer register: counts down at 60Hz, buzzer active while non-zero, deactivates at 0
    PC: u16 = 0, // program counter
    SP: u8 = 0, // stack pointer, up to 16 deep
};

const Keypad = enum(u8) {
    K1 = '1',
    K2 = '2',
    K3 = '3',
    KC = '4',
    K4 = 'q',
    K5 = 'w',
    K6 = 'e',
    KD = 'r',
    K7 = 'a',
    K8 = 's',
    K9 = 'd',
    KE = 'f',
    KA = 'z',
    K0 = 'x',
    KB = 'c',
    KF = 'v',
    _,
};

const GraphicsMode = enum {
    Mode64x32, // that is 64px wide and 32px tall
    Mode128x64,
};

// State of the system
const Chip8 = struct {
    registers: RegisterMap = .{},
    memory: [memory_size]u8 = [_]u8{0} ** memory_size,
    screen: [screen_height_2][screen_width_2]bool = .{[_]bool{false} ** screen_width_2} ** screen_height_2,

    // Only one thread may modify a value at a time
    delay_mutex: std.Thread.Mutex = .{},
    sound_mutex: std.Thread.Mutex = .{},
};

var chip8: Chip8 = .{};

// TODO
//  - store sprites for 0x0-0xF in interpreter memory

fn delayTimer() void {
    var dec: u8 = 1;
    while (true) {
        std.time.sleep(std.time.ns_per_s / 60);

        // Avoid waiting for lock, instead just decrement by one more if the lock can't be acquired
        if (chip8.delay_mutex.tryLock()) {
            defer chip8.delay_mutex.unlock();
            if (chip8.registers.DT > 0) {
                chip8.registers.DT -= dec;
            }
            dec = 1;
        } else {
            dec += 1;
        }
    }
}

fn soundTimer() void {
    var dec: u8 = 1;
    while (true) {
        std.time.sleep(std.time.ns_per_s / 60);

        // Avoid waiting for lock, instead just decrement by one more if the lock can't be acquired
        if (chip8.delay_mutex.tryLock()) {
            defer chip8.delay_mutex.unlock();
            if (chip8.registers.ST > 0) {
                chip8.registers.ST -= dec;
                // TODO emit a sound
            }
            dec = 1;
        } else {
            dec += 1;
        }
    }
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("Hello world\n", .{});

    // Timers must run at 60Hz, while CPU frequency is unspecified.
    var delay_thread = try std.Thread.spawn(.{}, delayTimer, .{});
    var sound_thread = try std.Thread.spawn(.{}, soundTimer, .{});
    delay_thread.detach();
    sound_thread.detach();

    chip8.delay_mutex.lock();
    chip8.registers.DT = 120;
    chip8.delay_mutex.unlock();

    while (chip8.registers.DT > 0) {
        std.time.sleep(std.time.ns_per_s / 15);
    }
}
