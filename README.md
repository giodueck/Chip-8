# Chip-8
Chip-8 emulator written in Zig to practice for more ambitious projects.

http://devernay.free.fr/hacks/chip8/C8TECH10.HTM is the documentation I used to get the specifications.

# Progress

Run tests with `zig build test` or `zig test src/test.zig`.

The test suite is the one at https://github.com/Timendus/chip8-test-suite. The current progress:

- [x] CHIP-8 splash screen
- [x] IBM Logo
- [x] Corax+ opcode test
- [ ] Flags test
- [x] Quirks test
- [ ] Keypad test
- [ ] Beep test
- [ ] Scrolling test
    - Depends if I implement Super Chip-8 as well
