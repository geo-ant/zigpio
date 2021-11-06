const std = @import("std");

const bcm2835 = @import("bcm2835.zig");
const peripherals = @import("peripherals.zig");

/// enumerates the GPio level (high/low)
pub const Level = enum(u1) { High = 0x1, Low = 0x0 };

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

/// describe the pull up / pull down mode for a given pin
pub const PullMode = enum(u2) {
    /// turn off the pull up or pull down line
    Off = 0b00,
    /// enable pull down
    PullDown = 0b01,
    /// enable pull up
    PullUp = 0b10,
};

/// Detection settings for a pin. The given values are optional bools. If 
/// null is given, then the value is left unchanged compared to the current setting
pub const Detection = struct {
    /// detect high
    high: ?bool = null,
    /// detect low
    low: ?bool = null,
    /// detect rising edge (synchronous)
    rising: ?bool = null,
    /// detect falling edge (synchronous)
    falling: ?bool = null,
};
/// error types
pub const Error = error{
    /// not initialized
    Uninitialized,
    /// Pin number out of range (or not available for this functionality)
    IllegalPinNumber,
    /// a mode value that could not be recognized was read from the register
    IllegalMode,
    /// event detection callback had already been set
    DectionCallbackAlreadySet,
};

/// if initialized points to the memory block that is provided by the gpio
/// memory mapping interface
var g_gpio_registers: ?peripherals.GpioRegisterMemory = null;

/// a callback function for event detection. This function will
/// be called from the event detection thread and 
var event_detection_callback : ?fn (pin_numbers: []const u8) void = null;

/// whether the event detection thread should shut down
var event_detection_thread_shutdown_request: std.atomic.Atomic(bool) = std.atomic.Atomic(bool).init(false);

/// if it exists, a handle for the event detection thread
var event_detection_thread: ?std.Thread = null;
/// condition variable that notifies the waiting event detection thread once a callback function for event detection is set.
var event_detection_function_set_condvar :std.Thread.Condition = std.Thread.Condition{};

/// initialize the GPIO control with the given memory mapping
pub fn init(memory_interface: *peripherals.GpioMemMapper) !void {
    g_gpio_registers = try memory_interface.memoryMap();
    event_detection_thread = try std.Thread.spawn(.{},detectionThreadLoop,.{});
}

/// deinitialize
/// This function will not release access of the GPIO memory, instead
/// it will perform some cleanup for the internals of this implementation
pub fn deinit() void {
    g_gpio_registers = null;
    if (event_detection_thread) |thread| {
        event_detection_thread_shutdown_request.store(true, .SeqCst);
        thread.join();
        event_detection_callback = null;
        event_detection_thread = null;
    }
}

/// write the given level to the pin
pub fn setLevel(pin_number: u8, level: Level) !void {
    try checkPinNumber(pin_number, bcm2835.BoardInfo);

    // register offset to find the correct set or clear register depending on the level:
    // setting works by writing a 1 to the bit that corresponds to the pin in the appropriate GPSET{n} register
    // and clearing works by writing a 1 to the bit that corresponds to the pin in the appropriate GPCLR{n} register
    // writing a 0 to those registers doesn't do anything
    const register_zero: u8 = switch (level) {
        .High => comptime gpioRegisterZeroIndex("GPSET", bcm2835.BoardInfo), // "set" GPSET{n} registers
        .Low => comptime gpioRegisterZeroIndex("GPCLR", bcm2835.BoardInfo), // "clear" GPCLR{n} registers
    };

    try setPinSingleBit(g_gpio_registers, .{ .pin_number = pin_number, .register_zero = register_zero }, 1);
}

/// get the level of the given pin
pub fn getLevel(pin_number: u8) !Level {
    const gplev_register_zero = comptime gpioRegisterZeroIndex("GPLEV", bcm2835.BoardInfo);

    const bit: u1 = try getPinSingleBit(g_gpio_registers, .{ .register_zero = gplev_register_zero, .pin_number = pin_number });
    if (bit == 0) {
        return .Low;
    } else {
        return .High;
    }
}

/// set the mode for the given pin.
pub fn setMode(pin_number: u8, mode: Mode) Error!void {
    var registers = g_gpio_registers orelse return Error.Uninitialized;
    try checkPinNumber(pin_number, bcm2835.BoardInfo);

    // a series of @bitSizeOf(Mode) is necessary to encapsulate the function of one pin
    // this is why we have to calculate the amount of pins that fit into a register by dividing
    // the number of bits in the register by the number of bits for the function
    // as of now 3 bits for the function and 32 bits for the register make 10 pins per register
    const pins_per_register = comptime @divTrunc(@bitSizeOf(peripherals.GpioRegister), @bitSizeOf(Mode));

    const gpfsel_register_zero = comptime gpioRegisterZeroIndex("GPFSEL", bcm2835.BoardInfo);
    const n: @TypeOf(pin_number) = @divTrunc(pin_number, pins_per_register);

    // set the bits of the corresponding pins to zero so that we can bitwise or the correct mask to it below
    registers[gpfsel_register_zero + n] &= clearMask(pin_number); // use bitwise-& here
    registers[gpfsel_register_zero + n] |= modeMask(pin_number, mode); // use bitwise-| here TODO, this is dumb, rework the mode setting mask to not have the inverse!
}

/// read the mode of the given pin number
pub fn getMode(pin_number: u8) !Mode {
    var registers = g_gpio_registers orelse return Error.Uninitialized;
    try checkPinNumber(pin_number, bcm2835.BoardInfo);

    const pins_per_register = comptime @divTrunc(@bitSizeOf(peripherals.GpioRegister), @bitSizeOf(Mode));
    const gpfsel_register_zero = comptime gpioRegisterZeroIndex("GPFSEL", bcm2835.BoardInfo);
    const n: @TypeOf(pin_number) = @divTrunc(pin_number, pins_per_register);

    const ModeIntType = (@typeInfo(Mode).Enum.tag_type);

    const ones: peripherals.GpioRegister = std.math.maxInt(ModeIntType);
    const shift_count = @bitSizeOf(Mode) * @intCast(u5, pin_number % pins_per_register);
    const stencil_mask = ones << shift_count;
    const mode_value = @intCast(ModeIntType, (registers[gpfsel_register_zero + n] & stencil_mask) >> shift_count);

    inline for (std.meta.fields(Mode)) |mode| {
        if (mode.value == mode_value) {
            return @intToEnum(Mode, mode.value);
        }
    }

    return Error.IllegalMode;
}

pub fn setPull(pin_number: u8, mode: PullMode) Error!void {
    var registers = g_gpio_registers orelse return Error.Uninitialized;

    // see the GPPUCLK register description for how to set the pull up or pull down on a per pin basis
    const gppud_register_zero = comptime gpioRegisterZeroIndex("GPPUD", bcm2835.BoardInfo);
    const gppudclk_register_zero = comptime gpioRegisterZeroIndex("GPPUDCLK", bcm2835.BoardInfo);
    const ten_us_in_ns = 10 * 1000;
    registers[gppud_register_zero] = @enumToInt(mode);
    // TODO this may be janky, because no precision of timing is guaranteed
    // however, the manual only states that we have to wait 150 clock cycles
    // and we are being very generous here
    std.os.nanosleep(0, ten_us_in_ns);

    try setPinSingleBit(registers, .{ .pin_number = pin_number, .register_zero = gppudclk_register_zero }, 1);

    std.os.nanosleep(0, ten_us_in_ns);
    registers[gppud_register_zero] = @enumToInt(PullMode.Off);
    try setPinSingleBit(registers, .{ .pin_number = pin_number, .register_zero = gppudclk_register_zero }, 0);
}

/// set the 
pub fn setDetectionMode(pin_number: u8, mode: Detection) !void {
    try checkPinNumber(pin_number, bcm2835.BoardInfo);

    // helper structure to define a helper function that sets the pin bit in the
    // given register based on a truth value
    const Lambda = struct {
        pub fn setBit(pin_num: u8, comptime register_name: []const u8, enable: bool) !void {
            try setPinSingleBit(g_gpio_registers, .{ .pin_number = pin_num, .register_zero = gpioRegisterZeroIndex(register_name, bcm2835.BoardInfo) }, if (enable) 1 else 0);
        }
    };

    if (mode.high) |enable_high| {
        try Lambda.setBit(pin_number, "GPHEN", enable_high);
    }
    if (mode.low) |enable_low| {
        try Lambda.setBit(pin_number, "GPLEN", enable_low);
    }
    if (mode.rising) |enable_rising| {
        try Lambda.setBit(pin_number, "GPREN", enable_rising);
    }
    if (mode.falling) |enable_falling| {
        try Lambda.setBit(pin_number, "GPFEN", enable_falling);
    }
}

/// set the callback function for event detection. Once this is function is called once,
/// calling it again will produce an error, if deinit() was not called previously
pub fn initDetectionCallback(callback : fn(pin_numbers : []const u8)void) !void {
    if(event_detection_callback!=null) {
        return Error.DectionCallbackAlreadySet;
    }
    _ = callback;
    event_detection_callback = callback;
    event_detection_function_set_condvar.signal();
}

/// the main loop of the detection thread that checks periodically if a detection event occurred
fn detectionThreadLoop() void {
    // although it is spawned on initialization, this thread is 
    // dormant until it is signalled via the condition variable
    var mtx = std.Thread.Mutex{};
    const held = mtx.acquire();
    event_detection_function_set_condvar.wait(&mtx);
    held.release();
}

const PinAndRegister = struct {
    pin_number: u8,
    register_zero: u8,
};

/// helper function for simplifying working with those contiguous registers where one GPIO bin is represented by one bit
/// needs the zero register for the set and the pin number and returns the bit (or an error)
inline fn getPinSingleBit(gpio_registers: ?peripherals.GpioRegisterMemory, pin_and_register: PinAndRegister) !u1 {
    var registers = gpio_registers orelse return Error.Uninitialized;
    const pin_number = pin_and_register.pin_number;
    const register_zero = pin_and_register.register_zero;
    try checkPinNumber(pin_number, bcm2835.BoardInfo);

    const pins_per_register = comptime @bitSizeOf(peripherals.GpioRegister);
    const n = @divTrunc(pin_number, pins_per_register);
    const pin_shift = @intCast(u5, pin_number % pins_per_register);

    const pin_value = registers[register_zero + n] & (@intCast(peripherals.GpioRegister, 1) << pin_shift);
    if (pin_value == 0) {
        return 0;
    } else {
        return 1;
    }
}

/// helper function for simplifying the work with those contiguous registers where one GPIO pin is represented by one bit
/// this function sets the respective bit to the given value
inline fn setPinSingleBit(gpio_registers: ?peripherals.GpioRegisterMemory, pin_and_register: PinAndRegister, value_to_set: u1) !void {
    var registers = gpio_registers orelse return Error.Uninitialized;
    const pin_number = pin_and_register.pin_number;
    const register_zero = pin_and_register.register_zero;
    try checkPinNumber(pin_number, bcm2835.BoardInfo);

    const pins_per_register = comptime @bitSizeOf(peripherals.GpioRegister);
    const n = @divTrunc(pin_number, pins_per_register);
    const pin_shift = @intCast(u5, pin_number % pins_per_register);
    if (value_to_set == 1) {
        registers[register_zero + n] |= (@intCast(peripherals.GpioRegister, 1) << pin_shift);
    } else {
        registers[register_zero + n] &= ~(@intCast(peripherals.GpioRegister, 1) << pin_shift);
    }
}

/// calculates that mask that sets the mode for a given pin in a GPFSEL register.
/// ATTENTION: before this function is called, the clearMask must be applied to this register
inline fn modeMask(pin_number: u8, mode: Mode) peripherals.GpioRegister {
    // a 32 bit register can only hold 10 pins, because a pin function is set by an u3 value.
    const pins_per_register = comptime @divTrunc(@bitSizeOf(peripherals.GpioRegister), @bitSizeOf(Mode));
    const pin_bit_idx = pin_number % pins_per_register;
    // shift the mode to the correct bits for the pin. Mode mask 0...xxx...0
    return @intCast(peripherals.GpioRegister, @enumToInt(mode)) << @intCast(u5, (pin_bit_idx * @bitSizeOf(Mode)));
}

/// get the zero register offset for the register of the given name
fn gpioRegisterZeroIndex(comptime register_name: []const u8, board_info: anytype) comptime_int {
    return comptime @field(board_info, register_name).zero_offset;

    //return comptime std.math.divExact(comptime_int, @field(board_info, register_name).start - board_info.gpio_registers.start, @sizeOf(peripherals.GpioRegister)) catch @compileError("Offset not evenly divisible by register width");
}

/// just a helper function that returns an error iff the given pin number is illegal
/// the board info type must carry a NUM_GPIO_PINS member field indicating the number of gpio pins
inline fn checkPinNumber(pin_number: u8, comptime BoardInfo: type) !void {
    if (@hasDecl(BoardInfo, "NUM_GPIO_PINS")) {
        if (pin_number < BoardInfo.NUM_GPIO_PINS) {
            return;
        } else {
            return Error.IllegalPinNumber;
        }
    } else {
        @compileError("BoardInfo type must have a constant field NUM_GPIO_PINS indicating the number of gpio pins");
    }
}

/// make a binary mask for clearing the associated region of th GPFSET register
/// this mask can be binary-ANDed to the GPFSEL register to set the bits of the given pin to 0
inline fn clearMask(pin_number: u8) peripherals.GpioRegister {
    const pins_per_register = comptime @divTrunc(@bitSizeOf(peripherals.GpioRegister), @bitSizeOf(Mode));
    const pin_bit_idx = pin_number % pins_per_register;
    // the input config should be zero
    // if it is, then the following logic will work
    comptime std.debug.assert(@enumToInt(Mode.Input) == 0);
    // convert the mode to a 3 bit integer: 0b000 (binary)
    // then invert the mode 111 (binary)
    // then convert this to an integer 000...000111 (binary) of register width
    // shift this by the appropriate amount (right now 3 bits per pin in a register)
    // 000...111...000
    // invert the whole thing and we end up with 111...000...111
    // we can bitwise and this to the register to clear the mode of the given pin
    // and prepare it for the set mode mask (which is bitwise or'd);
    return (~(@intCast(peripherals.GpioRegister, ~@enumToInt(Mode.Input)) << @intCast(u5, (pin_bit_idx * @bitSizeOf(Mode)))));
}

const testing = std.testing;

test "clearMask" {
    comptime std.debug.assert(@bitSizeOf(peripherals.GpioRegister) == 32);
    comptime std.debug.assert(@bitSizeOf(Mode) == 3);

    try testing.expect(clearMask(0) == 0b11111111111111111111111111111000);
    std.log.info("mode mask = {b}", .{modeMask(3, Mode.Input)});
    try testing.expect(clearMask(3) == 0b11111111111111111111000111111111);
    try testing.expect(clearMask(13) == 0b11111111111111111111000111111111);
}

test "modeMask" {
    // since the code below is manually verified for 32bit registers and 3bit function info
    // we have to make sure this still holds at compile time.
    comptime std.debug.assert(@bitSizeOf(peripherals.GpioRegister) == 32);
    comptime std.debug.assert(@bitSizeOf(Mode) == 3);

    // see online hex editor, e.g. https://hexed.it/
    try testing.expect(modeMask(0, Mode.Input) == 0);
    std.log.info("mode mask = {b}", .{modeMask(3, Mode.Input)});

    try testing.expect(modeMask(0, Mode.Output) == 0b00000000000000000000000000000001);
    try testing.expect(modeMask(3, Mode.Output) == 0b00000000000000000000001000000000);
    try testing.expect(modeMask(13, Mode.Alternate3) == 0b00000000000000000000111000000000);
}

test "gpioRegisterZeroIndex" {
    // the test is hand verified for 4 byte registers as is the case in the bcm2835
    // so we need to make sure this prerequisite is fulfilled
    comptime std.debug.assert(@sizeOf(peripherals.GpioRegister) == 4);
    // manually verified using the BCM2835 ARM Peripherals Manual
    const board_info = bcm2835.BoardInfo;
    try testing.expectEqual(0, gpioRegisterZeroIndex("GPFSEL", board_info));
    try testing.expectEqual(7, gpioRegisterZeroIndex("GPSET", board_info));
    try testing.expectEqual(10, gpioRegisterZeroIndex("GPCLR", board_info));
    try testing.expectEqual(13, gpioRegisterZeroIndex("GPLEV", board_info));
}

test "checkPinNumber" {
    const MyBoardInfo = struct {
        pub const NUM_GPIO_PINS: u8 = 20;
    };

    var pin: u8 = 0;
    while (pin < MyBoardInfo.NUM_GPIO_PINS) : (pin += 1) {
        try checkPinNumber(pin, MyBoardInfo);
    }

    while (pin < 2 * MyBoardInfo.NUM_GPIO_PINS) : (pin += 1) {
        try testing.expectError(Error.IllegalPinNumber, checkPinNumber(pin, MyBoardInfo));
    }
}

test "getPinSingleBit" {
    try std.testing.expectError(Error.Uninitialized, getPinSingleBit(null, .{ .pin_number = 1, .register_zero = 0 }));

    var three_registers = [3]peripherals.GpioRegister{ std.math.maxInt(peripherals.GpioRegister), 3, 5 };
    try std.testing.expectEqual(@intCast(u1, 1), try getPinSingleBit(&three_registers, .{ .pin_number = 0, .register_zero = 1 }));
    try std.testing.expectEqual(@intCast(u1, 1), try getPinSingleBit(&three_registers, .{ .pin_number = 1, .register_zero = 1 }));
    try std.testing.expectEqual(@intCast(u1, 0), try getPinSingleBit(&three_registers, .{ .pin_number = 2, .register_zero = 1 }));
    try std.testing.expectEqual(@intCast(u1, 1), try getPinSingleBit(&three_registers, .{ .pin_number = 32 + 0, .register_zero = 1 }));
    try std.testing.expectEqual(@intCast(u1, 0), try getPinSingleBit(&three_registers, .{ .pin_number = 32 + 1, .register_zero = 1 }));
    try std.testing.expectEqual(@intCast(u1, 1), try getPinSingleBit(&three_registers, .{ .pin_number = 32 + 2, .register_zero = 1 }));
}

test "setPinSingleBit" {
    var three_registers = [3]peripherals.GpioRegister{ 0, 0, 0 };
    // try setting bits
    try setPinSingleBit(&three_registers, .{ .pin_number = 0, .register_zero = 1 }, 1);
    try setPinSingleBit(&three_registers, .{ .pin_number = 1, .register_zero = 1 }, 1);
    try setPinSingleBit(&three_registers, .{ .pin_number = 3, .register_zero = 1 }, 1);
    try setPinSingleBit(&three_registers, .{ .pin_number = 32 + 2, .register_zero = 1 }, 1);
    // and then also unset bits that are zero anyways (these should have no influence on the values)
    try setPinSingleBit(&three_registers, .{ .pin_number = 32 + 3, .register_zero = 1 }, 0);
    try setPinSingleBit(&three_registers, .{ .pin_number = 2, .register_zero = 1 }, 0);
    try std.testing.expectEqual(@intCast(peripherals.GpioRegister, 0), three_registers[0]);
    try std.testing.expectEqual(@intCast(peripherals.GpioRegister, 1 + 2 + 8), three_registers[1]);
    try std.testing.expectEqual(@intCast(peripherals.GpioRegister, 4), three_registers[2]);
    // now unset a bit
    try setPinSingleBit(&three_registers, .{ .pin_number = 1, .register_zero = 1 }, 0);
    try std.testing.expectEqual(@intCast(peripherals.GpioRegister, 0), three_registers[0]);
    try std.testing.expectEqual(@intCast(peripherals.GpioRegister, 1 + 0 + 8), three_registers[1]);
    try std.testing.expectEqual(@intCast(peripherals.GpioRegister, 4), three_registers[2]);
}
