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
    I: u12 = 0, // memory address register, typically only lower 12 bits used
    DT: u8 = 0, // delay timer register: counts down at 60Hz, deactivates at 0
    ST: u8 = 0, // sound timer register: counts down at 60Hz, buzzer active while non-zero, deactivates at 0
    PC: u12 = 0, // program counter
    SP: u4 = 0, // stack pointer, up to 16 deep. We'll define it to be at interpreter memory address 0x000-00F
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

pub const GraphicsMode = enum(u1) {
    Mode64x32, // that is 64px wide and 32px tall
    Mode128x64,
};

// State of the system
pub const Chip8 = struct {
    registers: RegisterMap = .{},
    memory: [memory_size]u8 = [_]u8{0} ** memory_size,
    screen: [screen_height]u64 = [_]u64{0} ** screen_height,
    screen2: [screen_height_2]u128 = [_]u128{0} ** screen_height_2,
    active_graphics_mode: GraphicsMode = GraphicsMode.Mode64x32,

    // Only one thread may modify a value at a time
    delay_mutex: std.Thread.Mutex = .{},
    sound_mutex: std.Thread.Mutex = .{},

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
