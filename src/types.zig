const std = @import("std");

pub const register_count = 16;
pub const memory_size = 0x1000;
pub const memory_start = 0x200;
pub const memory_start_eti660 = 0x600;
pub const screen_width = 64;
pub const screen_height = 32;
pub const screen_width_2 = 128;
pub const screen_height_2 = 64;
pub const sprite_max_size = 15; // bytes, that is 8x15 bits

pub const RegisterMap = struct {
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

pub const Keypad = enum(u8) {
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

pub const GraphicsMode = enum {
    Mode64x32, // that is 64px wide and 32px tall
    Mode128x64,
};

// State of the system
pub const Chip8 = struct {
    registers: RegisterMap = .{},
    memory: [memory_size]u8 = [_]u8{0} ** memory_size,
    screen: [screen_height_2][screen_width_2]bool = .{[_]bool{false} ** screen_width_2} ** screen_height_2,
    active_graphics_mode: GraphicsMode = GraphicsMode.Mode64x32,

    // Only one thread may modify a value at a time
    delay_mutex: std.Thread.Mutex = .{},
    sound_mutex: std.Thread.Mutex = .{},
};

pub const Chip8Error = enum {
    Chip8MutexLocked,
};
