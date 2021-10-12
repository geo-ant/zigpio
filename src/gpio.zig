const std = @import("std");

const bcm2835 = @import("bcm2835.zig");
const peripherals = @import("peripherals.zig");

/// enumerates the GPio level (high/low)
pub const Level = enum {High, Low};

/// enumerates the gpio functionality
/// the enum values are the bits that need to be written into the
/// appropriate bits of the function select registers for a bin
/// see p 91,92 of http://www.raspberrypi.org/wp-content/uploads/2012/02/BCM2835-ARM-Peripherals.pdf
pub const Function = enum(u3) {
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


pub const Error = error {
    /// not initialized
    Unitialized,
    /// Pin number out of range (or not available for this functionality)
    IllegalPinNumber,
};

// TODO: make this an optional instance of the gpio mem region or something
// internal variable that indicates whether the gpio
// functionality was initialized
// var isInitialized : bool = false;

var g_gpio_registers :? peripherals.GpioRegisterMemory = null;

pub fn init(memory_interface : * peripherals.GpiomemMapper) !void {
    g_gpio_registers = try memory_interface.memoryMap();
}

// helper function to set a pin to high
fn write(pin_number : u8, level : Level) !void {
    var registers = g_gpio_registers orelse return Error.Unitialized;
    
    //TODO FACTOR OUT THE MAGIC NUMBERS
    if (pin_number > 53) {
        return Error.IllegalPinNumber;
    }
    // offset to the start of the gpio registers (which are the GPFSEL{n} registers)
    const register_offset = switch(level) {
        .High => 7, // "set" GPSET{n} registers
        .Low => 10, // "clear" GPCLR{n} registers
    };
    // which of the Set{n} (n=0,1) or GET{n}registers to use depends on which pin needs to be set#
    // because each of these registers hold 32 pins at most (the last one actually holds less)
    const n = pin_number % 32;

    registers[register_offset+n] |= 1 << n;
}

// pub fn 