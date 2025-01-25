const std = @import("std");
const ray = @import("raylib.zig");

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
    I: u12 = 0, // memory address register, typically only lower 12 bits used
    DT: u8 = 0, // delay timer register: counts down at 60Hz, deactivates at 0
    ST: u8 = 0, // sound timer register: counts down at 60Hz, buzzer active while non-zero, deactivates at 0
    PC: u12 = 0, // program counter
    SP: u4 = 0, // stack pointer, up to 16 deep. We'll define it to be at interpreter memory address 0x000-00F
};

pub const KeypadKey = enum(ray.KeyboardKey) {
    K1 = ray.KEY_ONE,
    K2 = ray.KEY_TWO,
    K3 = ray.KEY_THREE,
    KC = ray.KEY_FOUR,
    K4 = ray.KEY_Q,
    K5 = ray.KEY_W,
    K6 = ray.KEY_E,
    KD = ray.KEY_R,
    K7 = ray.KEY_A,
    K8 = ray.KEY_S,
    K9 = ray.KEY_D,
    KE = ray.KEY_F,
    KA = ray.KEY_Z,
    K0 = ray.KEY_X,
    KB = ray.KEY_C,
    KF = ray.KEY_V,
    _,
};

pub const GraphicsMode = enum(u1) {
    Mode64x32, // that is 64px wide and 32px tall
    Mode128x64,
};

const sprite_zero = .{
    0b11110000,
    0b10010000,
    0b10010000,
    0b10010000,
    0b11110000,
};
const sprite_one = .{
    0b00100000,
    0b01100000,
    0b00100000,
    0b00100000,
    0b01110000,
};
const sprite_two = .{
    0b11110000,
    0b00010000,
    0b11110000,
    0b10000000,
    0b11110000,
};
const sprite_three = .{
    0b11110000,
    0b00010000,
    0b11110000,
    0b00010000,
    0b11110000,
};
const sprite_four = .{
    0b10010000,
    0b10010000,
    0b11110000,
    0b00010000,
    0b00010000,
};
const sprite_five = .{
    0b11110000,
    0b10000000,
    0b11110000,
    0b00010000,
    0b11110000,
};
const sprite_six = .{
    0b11110000,
    0b10000000,
    0b11110000,
    0b10010000,
    0b11110000,
};
const sprite_seven = .{
    0b11110000,
    0b00010000,
    0b00100000,
    0b01000000,
    0b01000000,
};
const sprite_eight = .{
    0b11110000,
    0b10010000,
    0b11110000,
    0b10010000,
    0b11110000,
};
const sprite_nine = .{
    0b11110000,
    0b10010000,
    0b11110000,
    0b00010000,
    0b11110000,
};
const sprite_ten = .{
    0b11110000,
    0b10010000,
    0b11110000,
    0b10010000,
    0b10010000,
};
const sprite_eleven = .{
    0b11100000,
    0b10010000,
    0b11100000,
    0b10010000,
    0b11100000,
};
const sprite_twelve = .{
    0b11110000,
    0b10000000,
    0b10000000,
    0b10000000,
    0b11110000,
};
const sprite_thirteen = .{
    0b11100000,
    0b10010000,
    0b10010000,
    0b10010000,
    0b11100000,
};
const sprite_fourteen = .{
    0b11110000,
    0b10000000,
    0b11110000,
    0b10000000,
    0b11110000,
};
const sprite_fifteen = .{
    0b11110000,
    0b10000000,
    0b11110000,
    0b10000000,
    0b10000000,
};
const interpreter_memory = [_]u8{0} ** 32 ++ sprite_zero ++ sprite_one ++ sprite_two ++ sprite_three ++ sprite_four ++ sprite_five ++ sprite_six ++ sprite_seven ++ sprite_eight ++ sprite_nine ++ sprite_ten ++ sprite_eleven ++ sprite_twelve ++ sprite_thirteen ++ sprite_fourteen ++ sprite_fifteen;

// State of the system
pub const Chip8 = struct {
    registers: RegisterMap = .{},
    memory: [memory_size]u8 = interpreter_memory ++ [_]u8{0} ** (memory_size - interpreter_memory.len),
    screen: [screen_height]u64 = [_]u64{0} ** screen_height,
    screen2: [screen_height_2]u128 = [_]u128{0} ** screen_height_2,
    active_graphics_mode: GraphicsMode = GraphicsMode.Mode64x32,

    // Only one thread may modify a value at a time
    delay_mutex: std.Thread.Mutex = .{},
    sound_mutex: std.Thread.Mutex = .{},

    keypad: [16]bool = [_]bool{false} ** 16,

    freq: u32 = 500,

    // Helper functions
    pub fn getVx(self: anytype, x: u4) u8 {
        return switch (x) {
            0x0 => self.registers.V0,
            0x1 => self.registers.V1,
            0x2 => self.registers.V2,
            0x3 => self.registers.V3,
            0x4 => self.registers.V4,
            0x5 => self.registers.V5,
            0x6 => self.registers.V6,
            0x7 => self.registers.V7,
            0x8 => self.registers.V8,
            0x9 => self.registers.V9,
            0xA => self.registers.VA,
            0xB => self.registers.VB,
            0xC => self.registers.VC,
            0xD => self.registers.VD,
            0xE => self.registers.VE,
            0xF => self.registers.VF,
        };
    }
    pub fn setVx(self: anytype, x: u4, v: u8) void {
        switch (x) {
            0x0 => {
                self.registers.V0 = v;
            },
            0x1 => {
                self.registers.V1 = v;
            },
            0x2 => {
                self.registers.V2 = v;
            },
            0x3 => {
                self.registers.V3 = v;
            },
            0x4 => {
                self.registers.V4 = v;
            },
            0x5 => {
                self.registers.V5 = v;
            },
            0x6 => {
                self.registers.V6 = v;
            },
            0x7 => {
                self.registers.V7 = v;
            },
            0x8 => {
                self.registers.V8 = v;
            },
            0x9 => {
                self.registers.V9 = v;
            },
            0xA => {
                self.registers.VA = v;
            },
            0xB => {
                self.registers.VB = v;
            },
            0xC => {
                self.registers.VC = v;
            },
            0xD => {
                self.registers.VD = v;
            },
            0xE => {
                self.registers.VE = v;
            },
            0xF => {
                self.registers.VF = v;
            },
        }
    }
};

pub const Chip8Error = enum {
    Chip8MutexLocked,
};

pub const Interrupt = error{
    Vblank,
};
