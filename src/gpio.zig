const std = @import("std");

const bcm2835 = @import("bcm2835.zig");
const peripherals = @import("peripherals.zig");

/// enumerates the GPio level (high/low)
pub const Level = enum { High, Low };

/// enumerates the gpio functionality
/// the enum values are the bits that need to be written into the
/// appropriate bits of the function select registers for a bin
/// see p 91,92 of http://www.raspberrypi.org/wp-content/uploads/2012/02/BCM2835-ARM-Peripherals.pdf
pub const Mode = enum(u3) {
    /// intput functionality
    Input = 0b000,
    /// output functionality
    Output = 0b001,
    /// not yet implemented 
    Alternate0 = 0b100,
    /// not yet implemented 
    Alternate1 = 0b101,
    /// not yet implemented 
    Alternate2 = 0b110,
    /// not yet implemented 
    Alternate3 = 0b111,
    /// not yet implemented 
    Alternate4 = 0b011,
    /// not yet implemented 
    Alternate5 = 0b010,
};

pub const Error = error{
    /// not initialized
    Unitialized,
    /// Pin number out of range (or not available for this functionality)
    IllegalPinNumber,
};

/// if initialized points to the memory block that is provided by the gpio
/// memory mapping interface
var g_gpio_registers: ?peripherals.GpioRegisterMemory = null;

/// initialize the GPIO control with the given memory mapping
pub fn init(memory_interface: *peripherals.GpiomemMapper) !void {
    g_gpio_registers = try memory_interface.memoryMap();
}

/// deinitialize
/// This function will not release access of the GPIO memory
pub fn deinit() void {
    g_gpio_registers = null;
}

// write the given level to the pin
pub fn setLevel(pin_number: u8, level: Level) !void {
    var registers = g_gpio_registers orelse return Error.Unitialized;

    if (pin_number > bcm2835.BoardInfo.NUM_GPIO_PINS) {
        return Error.IllegalPinNumber;
    }
    const gpio_start = bcm2835.BoardInfo.gpio_registers.start;
    // register offset to find the correct set or clear register depending on the level:
    // setting works by writing a 1 to the bit that corresponds to the pin in the appropriate GPSET{n} register
    // and clearing works by writing a 1 to the bit that corresponds to the pin in the appropriate GPCLR{n} register
    // writing a 0 to those registers doesn't do anything
    const register_offset = switch (level) {
        .High => bcm2835.BoardInfo.gpset_registers.start - gpio_start, // "set" GPSET{n} registers
        .Low => bcm2835.BoardInfo.gpclr_registers.start - gpio_start, // "clear" GPCLR{n} registers
    };
    // which of the Set{n} (n=0,1) or GET{n}registers to use depends on which pin needs to be set#
    // because each of these registers hold 32 pins at most (the last one actually holds less)
    const n = pin_number % @bitSizeOf(peripherals.GpioRegister);
    registers[register_offset + n] |= @intCast(peripherals.GpioRegister,1) << @intCast(u5,n);
}

//TODO function getLevel

pub fn setMode(pin_number: u8, mode: Mode) !void {
    var registers = g_gpio_registers orelse return Error.Unitialized;
    if (pin_number > bcm2835.BoardInfo.NUM_GPIO_PINS) {
        return Error.IllegalPinNumber;
    }
    // a series of @bitSizeOf(Mode) is necessary to encapsulate the function of one pin
    // this is why we have to calculate the amount of pins that fit into a register by dividing
    // the number of bits in the register by the number of bits for the function
    // as of now 3 bits for the function and 32 bits for the register make 10 pins per register
    const pins_per_register = comptime @divTrunc(@bitSizeOf(peripherals.GpioRegister), @bitSizeOf(Mode));
    
    /////////TODO TODO TODO!!!!!!!!!!
    // this offset is wrong since the starts are in bytes by the register width is 4 bytes
    // make a better comptime function in the info structure that gives me the offset in registers 
    // something like ... i dont't knwo too tired to think of a good name
    
    const gpfsel_register_offset = comptime bcm2835.BoardInfo.gpfsel_registers.start - bcm2835.BoardInfo.gpio_registers.start;
    const n: @TypeOf(pin_number) = @divTrunc(pin_number, pins_per_register);

    // the input functionality clears the register, which is why we apply it alway
    // (see https://github.com/ziglang/zig/issues/7605 for why we have to cast)
    const input_and_clear_mask = modeMask(pin_number, Mode.Input);
    registers[gpfsel_register_offset + n] &= input_and_clear_mask;

    const mode_setting_mask = modeMask(pin_number, mode);
    registers[gpfsel_register_offset + n] &= mode_setting_mask;
}

//TODO
// pub fn getMode(pin_number : u8, mode : Mode) !Mode {
//     //TODO: check if it is valid to read the mode!
//     //we should be able to do some elegant comptime magic by extracting the mode from the register
//     //shifting it and casting it into u3 and then INLINE FOR-ING through the enum variants
//     //and comparing it to the variants in the enum. if none matches => error
// }

/// calculates the mask that needs to be shifted to the correct pin and
/// bitwise anded to the register to set the desired mode for that pin
inline fn modeMask(pin_number: u8, mode: Mode) peripherals.GpioRegister {
    const pins_per_register = comptime @divTrunc(@bitSizeOf(peripherals.GpioRegister), @bitSizeOf(Mode));
    const pin_bit_idx = pin_number % pins_per_register;

    // convert the mode to a 3 bit integer: xyz (binary)
    // then invert the mode abc = ~xyz (binary)
    // then convert this to an integer 000...000abc (binary) of register width
    // shift this by the appropriate amount (right now 3 bits per pin in a register)
    // 000...abc...000
    // invert the whole thing and we end up with 111...xyz...111
    // we can bitwise and this to the register to set the mode of the given pin
    return (~(@intCast(peripherals.GpioRegister, ~@enumToInt(mode)) << @intCast(u5, (pin_bit_idx * @bitSizeOf(Mode)))));
}
