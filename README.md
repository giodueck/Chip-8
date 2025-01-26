# Chip-8
Chip-8 emulator written in Zig to practice for more ambitious projects.


# Building

To build, simply run `zig build`. This will fetch Raylib and build it from source, in addition to the emulator.
The binary will then be in `zig-out/bin/chip-8`.

# Running programs

To run a program run:
```sh
./zig-out/bin/chip-8 program.ch8
```

A Chip-8 program consists of a binary file which is loaded into the system's memory and executed. The test roms included in `roms/` (source in the Progress & Tests section below) are examples of Chip-8 programs made to test the emulator's accuracy.

For normal programs and games, including ones originally made for Chip-8 interpreters of the gool ol' days, one source is [here](https://github.com/kripod/chip8-roms/tree/master), but there are many more.

# Progress & Tests

Run tests with `zig build test` or `zig test src/test.zig`.

The test suite is the one at https://github.com/Timendus/chip8-test-suite. The current progress:

- [x] CHIP-8 splash screen
- [x] IBM Logo
- [x] Corax+ opcode test
- [x] Flags test
- [x] Quirks test
- [x] Keypad test
- [x] Beep test

Some parts of the code were made with possible variant support in mind. In case I ever implement Super Chip-8:
- [ ] Quirks test
- [ ] Scrolling test

# Resources

- http://devernay.free.fr/hacks/chip8/C8TECH10.HTM is the documentation I used to get the specifications.
- https://github.com/Timendus/chip8-test-suite contains testing programs and some more documentation regarding quirks of the original interpreters. They are licensed under GPL-3.0.
- https://discord.gg/dkmJAes is the Emulator Development Discord server with many helpful resources and people.
