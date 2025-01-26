const std = @import("std");
const c8 = struct {
    usingnamespace @import("types.zig");
    usingnamespace @import("registers.zig");
};
// const stderr = std.io.getStdErr().writer();

/// Runs a single instruction: fetch from memory, decode and execute, and update PC accordingly.
/// The only errors are interrupts
pub fn runInstruction(chip8: *c8.Chip8) c8.Interrupt!void {
    // Fetch
    if (chip8.registers.PC & 1 != 0) {
        // This is an invalid instruction location, assume padding is wrong and increment to make PC even
        chip8.registers.PC += 1;
    }

    // stderr.print("{d}\n", .{chip8.registers.PC}) catch {};
    // stderr.print("{d}\n", .{chip8.memory[chip8.registers.PC]}) catch {};

    const instr: u16 = @as(u16, chip8.memory[chip8.registers.PC]) << 8 | chip8.memory[chip8.registers.PC + 1];

    // Decode & Execute
    // instruction nibbles
    const inib: [4]u4 = .{ @truncate((instr >> 12) & 0xF), @truncate((instr >> 8) & 0xF), @truncate((instr >> 4) & 0xF), @truncate(instr & 0xF) };

    // stderr.print("{d}\n", .{instr}) catch {};
    // stderr.print("{d}\n", .{inib}) catch {};

    var inc_PC = true;
    var int: ?c8.Interrupt = null;
    switch (inib[0]) {
        0x0 => {
            if (instr == 0x00E0) {
                // CLS: clear screen
                clearScreen(chip8);
            } else if (instr == 0x00EE) {
                // RET: return from subroutine
                chip8.registers.SP -%= 1;
                // SP points to 16-bit values, so multiply the address by 2
                chip8.registers.PC = @truncate(@as(u16, chip8.memory[chip8.registers.SP * 2]) << 8 | @as(u16, chip8.memory[chip8.registers.SP * 2 + 1]));
                // Let PC increment by 2 at the end of this function to go past the CALL that this will point to
            }
        },
        0x1 => {
            // JP addr: jump
            chip8.registers.PC = @truncate(instr & 0x0FFF);
            inc_PC = false;
        },
        0x2 => {
            // CALL addr: call subroutine
            // SP points to 16-bit values, so multiply the address by 2
            chip8.memory[chip8.registers.SP * 2] = @truncate(chip8.registers.PC >> 8);
            chip8.memory[chip8.registers.SP * 2 + 1] = @truncate(chip8.registers.PC & 0xFF);
            chip8.registers.SP +%= 1;
            chip8.registers.PC = @truncate(instr & 0x0FFF);
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
            if (inib[3] == 0x0) {
                if (chip8.getVx(inib[1]) == chip8.getVx(inib[2])) {
                    chip8.registers.PC +%= 2;
                }
            } // else NOOP: illegal instruction
        },
        0x6 => {
            // LD Vx, byte: set Vx = byte
            // 6xkk
            chip8.setVx(inib[1], @truncate(instr & 0xFF));
        },
        0x7 => {
            // ADD Vx, byte: set Vx = Vx + byte
            // 7xkk
            const vx = chip8.getVx(inib[1]);
            chip8.setVx(inib[1], vx +% @as(u8, @truncate(instr & 0xFF)));
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
                    chip8.setVx(0xF, 0);
                },
                0x2 => {
                    // AND Vx, Vy: set Vx = Vx AND Vy
                    const vx = chip8.getVx(inib[1]);
                    const vy = chip8.getVx(inib[2]);
                    chip8.setVx(inib[1], vx & vy);
                    chip8.setVx(0xF, 0);
                },
                0x3 => {
                    // XOR Vx, Vy: set Vx = Vx XOR Vy
                    const vx = chip8.getVx(inib[1]);
                    const vy = chip8.getVx(inib[2]);
                    chip8.setVx(inib[1], vx ^ vy);
                    chip8.setVx(0xF, 0);
                },
                0x4 => {
                    // ADD Vx, Vy: set Vx = Vx + Vy, set VF = carry
                    const vx = chip8.getVx(inib[1]);
                    const vy = chip8.getVx(inib[2]);
                    const add_res = @addWithOverflow(vx, vy);
                    chip8.setVx(inib[1], add_res.@"0");
                    chip8.setVx(0xF, add_res.@"1");
                },
                0x5 => {
                    // SUB Vx, Vy: set Vx = Vx - Vy, set VF = NOT borrow
                    const vx = chip8.getVx(inib[1]);
                    const vy = chip8.getVx(inib[2]);
                    const sub_res = @subWithOverflow(vx, vy);
                    chip8.setVx(inib[1], sub_res.@"0");
                    chip8.setVx(0xF, 1 - sub_res.@"1");
                },
                0x6 => {
                    // SHR Vx {, Vy}: set Vx = Vx >> 1, set VF = least signifficant bit in Vx before shift
                    const vy = chip8.getVx(inib[2]);
                    const f: u1 = @truncate(vy & 1);
                    chip8.setVx(inib[1], vy >> 1);
                    chip8.setVx(0xF, f);
                },
                0x7 => {
                    // SUBN Vx, Vy: set Vx = Vy - Vx, set VF = NOT borrow
                    const vx = chip8.getVx(inib[1]);
                    const vy = chip8.getVx(inib[2]);
                    const sub_res = @subWithOverflow(vy, vx);
                    chip8.setVx(inib[1], sub_res.@"0");
                    chip8.setVx(0xF, 1 - sub_res.@"1");
                },
                0xE => {
                    // SHL Vx , Vy: set Vx = Vy << 1, set VF = most signifficant bit in Vx before shift
                    const vy = chip8.getVx(inib[2]);
                    const f: u1 = @truncate((vy >> 7) & 1);
                    chip8.setVx(inib[1], vy << 1);
                    chip8.setVx(0xF, f);
                },
                else => {
                    // NOOP: illegal instruction
                },
            }
        },
        0x9 => {
            // SNE Vx, Vy: skip next instruction if Vx != Vy
            if (inib[3] == 0x0) {
                if (chip8.getVx(inib[1]) != chip8.getVx(inib[2])) {
                    chip8.registers.PC +%= 2;
                }
            } // else NOOP: illegal instruction
        },
        0xA => {
            // LD I, addr: set I = addr
            chip8.registers.I = @truncate(instr & 0xFFF);
        },
        0xB => {
            // JP V0, addr: jump to addr + V0
            chip8.registers.PC = chip8.registers.V0 + @as(u12, @intCast(instr & 0xFFF));
            inc_PC = false;
        },
        0xC => {
            // RND Vx, byte: set Vx = random byte AND byte
            // Cxkk
            var rnd: [1]u8 = .{0};
            std.posix.getrandom(&rnd) catch {
                rnd[0] = @as(u8, @truncate(chip8.registers.PC)) *% 0x65;
            };
            chip8.setVx(inib[1], rnd[0] & @as(u8, @intCast(instr & 0xFF)));
        },
        0xD => {
            // DRW Vx, Vy, nibble: dispay n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision
            const f = drawSprite(chip8, inib[1], inib[2], inib[3]);
            chip8.setVx(0xF, f);
            int = c8.Interrupt.Vblank;
        },
        0xE => {
            if ((instr & 0xFF) == 0x9E) {
                // SKP Vx: skip next instruction if key with the value of Vx is pressed
                if (chip8.keypad[chip8.getVx(inib[1])]) {
                    chip8.registers.PC +%= 2;
                }
            } else if ((instr & 0xFF) == 0xA1) {
                // SKNP Vx: skip next instruction if key with the value of Vx is not pressed
                if (!chip8.keypad[chip8.getVx(inib[1])]) {
                    chip8.registers.PC +%= 2;
                }
            }
        },
        0xF => {
            switch (instr & 0xFF) {
                0x07 => {
                    // LD Vx, DT: set Vx = delay timer value
                    {
                        chip8.delay_mutex.lock();
                        defer chip8.delay_mutex.unlock();

                        chip8.setVx(inib[1], chip8.registers.DT);
                    }
                },
                0x0A => {
                    // LD Vx, K: wait for a key press, store the value of the key in Vx
                    for (chip8.keypad, 0..) |k, i_| {
                        const i: u8 = @intCast(i_);
                        if (k) {
                            chip8.setVx(inib[1], i);
                            break;
                        }
                    } else {
                        // repeat this instruction
                        inc_PC = false;
                    }
                },
                0x15 => {
                    // LD DT, Vx: set delay timer = Vx
                    {
                        chip8.delay_mutex.lock();
                        defer chip8.delay_mutex.unlock();

                        chip8.registers.DT = chip8.getVx(inib[1]);
                    }
                },
                0x18 => {
                    // LD ST, Vx: set sound timer = Vx
                    {
                        chip8.sound_mutex.lock();
                        defer chip8.sound_mutex.unlock();

                        chip8.registers.ST = chip8.getVx(inib[1]);
                    }
                },
                0x1E => {
                    // ADD I, Vx: set I = I + Vx
                    chip8.registers.I +%= chip8.getVx(inib[1]);
                },
                0x29 => {
                    // LD F, Vx: set I = location of sprite for digit Vx
                    // Sprites located at 32 + sprite_i * 5 (stack = 32B, sprite = 5B)
                    const v: u12 = chip8.getVx(inib[1]) & 0xF;
                    chip8.registers.I = 32 + v * 5;
                },
                0x33 => {
                    // LD B, Vx: store BCD representation of Vx in memory locations I, I+1, and I+2
                    const v = chip8.getVx(inib[1]);
                    chip8.memory[chip8.registers.I] = v / 100;
                    chip8.memory[chip8.registers.I +| 1] = (v % 100) / 10;
                    chip8.memory[chip8.registers.I +| 2] = v % 10;
                },
                0x55 => {
                    // LD [I], Vx: store registers V0 through Vx in memory starting at location I
                    for (0..inib[1] + 1) |_x| {
                        const x = @as(u4, @truncate(_x));
                        chip8.memory[chip8.registers.I] = chip8.getVx(x);
                        chip8.registers.I +%= 1;
                    }
                },
                0x65 => {
                    // LD Vx, [I]: load registers V0 through Vx from memory starting at location I
                    for (0..inib[1] + 1) |_x| {
                        const x = @as(u4, @truncate(_x));
                        chip8.setVx(x, chip8.memory[chip8.registers.I]);
                        chip8.registers.I +%= 1;
                    }
                },
                else => {
                    // NOOP: illegal instruction
                },
            }
        },
    }

    // Post-execution
    if (inc_PC) chip8.registers.PC +%= 2;

    if (int) |interrupt| return interrupt;
}

fn clearScreen(chip8: *c8.Chip8) void {
    switch (chip8.active_graphics_mode) {
        c8.GraphicsMode.Mode64x32 => {
            for (0..chip8.screen.len) |i| {
                chip8.screen[i] = 0;
            }
        },
        c8.GraphicsMode.Mode128x64 => {
            for (0..chip8.screen2.len) |i| {
                chip8.screen2[i] = 0;
            }
        },
    }
}

/// Draws n-byte sprite at address I at (x, y).
/// Returns 1 if there was a collision
fn drawSprite(chip8: *c8.Chip8, x: u4, y: u4, n: u4) u1 {
    var collision = false;
    const px = chip8.getVx(x) % 0x40;
    const py = chip8.getVx(y) % 0x20;
    switch (chip8.active_graphics_mode) {
        c8.GraphicsMode.Mode64x32 => {
            for (0..n) |i| {
                if (py + i >= chip8.screen.len) break;

                const sprite_row: u64 = chip8.memory[chip8.registers.I + i];
                const shifted = @as(u64, @intCast(std.math.shl(i65, sprite_row, 64 - 8 - @as(i65, px))));

                if ((chip8.screen[py + i] & shifted) > 0) collision = true;
                chip8.screen[py + i] ^= shifted;
            }
        },
        c8.GraphicsMode.Mode128x64 => {
            for (0..n) |i| {
                if (py + i >= chip8.screen.len) break;

                const sprite_row: u128 = chip8.memory[chip8.registers.I + i];
                const shifted = @as(u128, @intCast(std.math.shl(i129, sprite_row, @as(i129, 128 - 8) - px)));

                if ((chip8.screen2[py + i] & shifted) > 0) collision = true;
                chip8.screen2[py + i] ^= shifted;
            }
        },
    }
    return if (collision) 1 else 0;
}
