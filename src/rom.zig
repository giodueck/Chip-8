const std = @import("std");
const c8 = struct {
    usingnamespace @import("types.zig");
    usingnamespace @import("registers.zig");
    usingnamespace @import("cpu.zig");
};

const stderr = std.io.getStdErr().writer();

pub fn load_rom(program_name: []const u8, program_bin: []u8) !usize {
    const cwd = std.fs.cwd();
    const program_fd = std.fs.Dir.openFile(cwd, program_name, .{});
    var program_len: usize = 0;
    if (program_fd) |fd| {
        defer std.fs.File.close(fd);
        program_len = std.fs.File.readAll(fd, program_bin[0x200..program_bin.len]) catch |err| {
            try stderr.print("Could not read file '{s}': {}\n", .{ program_name, err });
            return err;
        };
    } else |err| {
        try stderr.print("Could not open file '{s}': {}\n", .{ program_name, err });
        return err;
    }
    return program_len;
}

pub fn set_rom(chip8: *c8.Chip8, program: []u8, program_len: usize) void {
    // Copy program
    for (program[0x200..(0x200 + program_len)], 0x200..) |b, i| {
        chip8.memory[i] = b;
        // try stderr.print("{x:0^2}\n", .{chip8.memory[i]});
    }
    // Entry point for most Chip-8 programs
    chip8.registers.PC = 0x200;
}
