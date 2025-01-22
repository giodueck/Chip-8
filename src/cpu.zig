const std = @import("std");
const c8 = struct {
    usingnamespace @import("types.zig");
    usingnamespace @import("registers.zig");
};

/// Runs a single instruction: fetch from memory, decode and execute, and update PC accordingly.
pub fn runInstruction(chip8: *c8.Chip8) void {
    // Fetch
    if (chip8.registers.PC & 1 != 0) {
        // This is an invalid instruction location, assume padding is wrong and increment to make PC even
        chip8.registers.PC += 1;
    }
    const instr: u16 = @as(u16, chip8.memory[chip8.registers.PC & (1 << 12 - 1)]) << 8 | chip8.memory[chip8.registers.PC & (1 << 12 - 1)];

    // Decode & Execute
    const inib: [4]u4 = .{ @as(u4, instr >> 12), @as(u4, (instr >> 8) & 0xF), @as(u4, (instr >> 4) & 0xF), @as(u4, instr & 0xF) }; // instruction nibbles

    var inc_PC = true;
    switch (inib[0]) {
        0x0 => {
            if (instr == 0x00E0) {
                // CLS: clear screen
                clearScreen(chip8);
            } else if (instr == 0x00EE) {
                // RET: return from subroutine
                chip8.registers.PC = chip8.memory[chip8.registers.SP - 1];
                chip8.registers.SP -%= 1;
                // Let PC increment by 2 at the end of this function to go past the CALL that this will point to
            }
        },
        0x1 => {
            // JP addr: jump
            chip8.registers.PC = instr & 0x0FFF;
            inc_PC = false;
        },
        0x2 => {
            // CALL addr: call subroutine
            chip8.memory[chip8.registers.SP] = chip8.registers.PC;
            chip8.registers.SP +%= 1;
            chip8.registers.PC = instr & 0x0FFF;
            inc_PC = false;
        },
        0x3 => {
            // SE Vx, byte: skip next instruction if Vx = byte
            // 3xkk
            if (chip8.getVx(inib[1]) == (instr & 0xFF)) {
                chip8.registers.PC +%= 2;
            }
        },
        0x4 => {
            // SNE Vx, byte: skip next instruction if Vx != byte
            // 4xkk
            if (chip8.getVx(inib[1]) != (instr & 0xFF)) {
                chip8.registers.PC +%= 2;
            }
        },
        0x5 => {
            // SE Vx, Vy: skip next instruction if Vx = Vy
            // 5xy0
            if (chip8.getVx(inib[1]) == chip8.getVx(inib[2])) {
                chip8.registers.PC +%= 2;
            }
        },
        0x6 => {
            // LD Vx, byte: set Vx = byte
            // 6xkk
            chip8.setVx(inib[1], instr & 0xFF);
        },
        0x7 => {
            // ADD Vx, byte: set Vx = Vx + byte
            // 7xkk
            const vx = chip8.getVx(inib[1]);
            chip8.setVx(inib[1], vx +% instr & 0xFF);
        },
        0x8 => {
            // 8xyn
            switch (inib[3]) {
                0x0 => {
                    // LD Vx, Vy: set Vx = Vy
                    const vy = chip8.getVx(inib[2]);
                    chip8.setVx(inib[1], vy);
                },
                0x1 => {
                    // OR Vx, Vy: set Vx = Vx OR Vy
                    const vx = chip8.getVx(inib[1]);
                    const vy = chip8.getVx(inib[2]);
                    chip8.setVx(inib[1], vx | vy);
                },
                0x2 => {
                    // AND Vx, Vy: set Vx = Vx AND Vy
                    const vx = chip8.getVx(inib[1]);
                    const vy = chip8.getVx(inib[2]);
                    chip8.setVx(inib[1], vx & vy);
                },
                0x3 => {
                    // XOR Vx, Vy: set Vx = Vx XOR Vy
                    const vx = chip8.getVx(inib[1]);
                    const vy = chip8.getVx(inib[2]);
                    chip8.setVx(inib[1], vx ^ vy);
                },
                0x4 => {
                    // ADD Vx, Vy: set Vx = Vx + Vy, set VF = carry
                    const vx = chip8.getVx(inib[1]);
                    const vy = chip8.getVx(inib[2]);
                    const add_res: struct { result: @TypeOf(vx), carry: u1 } = @addWithOverflow(vx, vy);
                    chip8.setVx(inib[1], add_res.result);
                    chip8.setVx(0xF, add_res.carry);
                },
                0x5 => {
                    // SUB Vx, Vy: set Vx = Vx - Vy, set VF = NOT borrow
                    const vx = chip8.getVx(inib[1]);
                    const vy = chip8.getVx(inib[2]);
                    const sub_res: struct { result: @TypeOf(vx), carry: u1 } = @addWithOverflow(vx, -vy);
                    chip8.setVx(inib[1], sub_res.result);
                    chip8.setVx(0xF, sub_res.carry);
                },
                0x6 => {
                    // SHR Vx {, Vy}: set Vx = Vx >> 1, set VF = least signifficant bit in Vx before shift
                    const vx = chip8.getVx(inib[1]);
                    const f: u1 = vx & 1;
                    chip8.setVx(inib[1], vx >> 1);
                    chip8.setVx(0xF, f);
                },
                0x7 => {
                    // SUBN Vx, Vy: set Vx = Vy - Vx, set VF = NOT borrow
                    const vx = chip8.getVx(inib[1]);
                    const vy = chip8.getVx(inib[2]);
                    const sub_res: struct { result: @TypeOf(vx), carry: u1 } = @addWithOverflow(vy, -vx);
                    chip8.setVx(inib[1], sub_res.result);
                    chip8.setVx(0xF, sub_res.carry);
                },
                0xE => {
                    // SHL Vx {, Vy}: set Vx = Vx << 1, set VF = most signifficant bit in Vx before shift
                    const vx = chip8.getVx(inib[1]);
                    const f: u1 = (vx >> 7) & 1;
                    chip8.setVx(inib[1], vx << 1);
                    chip8.setVx(0xF, f);
                },
                else => {
                    // NOOP: illegal instruction
                },
            }
        },
        0x9 => {
            // SNE Vx, Vy: skip next instruction if Vx != Vy
        },
        0xA => {
            // LD I, addr: set I = addr
            chip8.registers.I = instr & 0xFFF;
        },
        0xB => {
            // JP V0, addr: jump to addr + V0
        },
        0xC => {
            // RND Vx, byte: set Vx = random byte AND byte
        },
        0xD => {
            // DRW Vx, Vy, nibble: dispay n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision
            chip8.setVx(0xF, drawSprite(chip8, inib[1], inib[2], inib[3]));
        },
        0xE => {
            if ((instr & 0xFF) == 0x9E) {
                // SKP Vx: skip next instruction if key with the value of Vx is pressed
            } else if ((instr & 0xFF) == 0xA1) {
                // SKNP Vx: skip next instruction if key with the value of Vx is not pressed
            }
        },
        0xF => {
            switch (instr & 0xFF) {
                0x07 => {
                    // LD Vx, DT: set Vx = delay timer value
                },
                0x0A => {
                    // LD Vx, K: wait for a key press, store the value of the key in Vx
                },
                0x15 => {
                    // LD DT, Vx: set delay timer = Vx
                },
                0x18 => {
                    // LD ST, Vx: set sound timer = Vx
                },
                0x1E => {
                    // ADD I, Vx: set I = I + Vx
                },
                0x29 => {
                    // LD F, Vx: set I = location of sprite for digit Vx
                },
                0x33 => {
                    // LD B, Vx: store BCD representation of Vx in memory locations I, I+1, and I+2
                },
                0x55 => {
                    // LD [I], Vx: store registers V0 through Vx in memory starting at location I
                },
                0x65 => {
                    // LD Vx, [I]: load registers V0 through Vx from memory starting at location I
                },
                else => {
                    // NOOP: illegal instruction
                },
            }
        },
    }

    // Post-execution
    chip8.registers.PC +%= 2;
}

fn clearScreen(chip8: *c8.Chip8) void {
    switch (chip8.active_graphics_mode) {
        c8.GraphicsMode.Mode64x32 => {
            for (chip8.screen) |row| {
                row = 0;
            }
        },
        c8.GraphicsMode.Mode128x64 => {
            for (chip8.screen2) |row| {
                row = 0;
            }
        },
    }
}

/// Draws n-byte sprite at address I at (x, y).
/// Returns 1 if there was a collision
fn drawSprite(chip8: *c8.Chip8, x: u4, y: u4, n: u4) u1 {
    var collision: u1 = 0;
    switch (chip8.active_graphics_mode) {
        c8.GraphicsMode.Mode64x32 => {
            // TODO handle sprites going off the sides
            for (0..n) |i| {
                const sprite_row: u8 = chip8.memory[chip8.registers.I + i];
                collision |= (chip8.screen[y + i] & (sprite_row << (64 - 8 - x))) > 0;
                chip8.screen[y + i] ^= sprite_row << (64 - 8 - x);
            }
        },
        c8.GraphicsMode.Mode128x64 => {
            for (0..n) |i| {
                const sprite_row: u8 = chip8.memory[chip8.registers.I + i];
                collision |= (chip8.screen2[y + i] & (sprite_row << (128 - 8 - x))) > 0;
                chip8.screen2[y + i] ^= sprite_row << (128 - 8 - x);
            }
        },
    }
}
