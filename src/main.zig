const std = @import("std");

const bcm2835 = @import("bcm2835.zig");

const mocks = @import("integration-tests/mocks.zig");

const gpio = @import("gpio.zig");

pub fn main() anyerror!void {

    var mapper = try bcm2835.Bcm2385GpioMemoryInterface.init();
    defer mapper.deinit();

    try gpio.init(&mapper.memory_mapper);

    //try setAllPinModes(.Output);
    const pin_number = 3;
    try gpio.setMode(pin_number, gpio.Mode.Output);

    _ = try gpio.getMode(pin_number);

    var idx: u32 = 0;
    while (idx < 100) : (idx += 1) {
        std.log.info("idx {}", .{idx});
        std.log.info("set pin to high", .{});
        try gpio.setLevel(pin_number, .High);
        std.time.sleep(500000000); //500ms
        std.log.info("set pin to low", .{});
        try gpio.setLevel(pin_number, .Low);
        std.time.sleep(500000000); //500ms
    }
}

fn setAllPinLevels(level: gpio.Level) !void {
    var pin: u8 = 0;
    while (pin < bcm2835.BoardInfo.NUM_GPIO_PINS) : (pin += 1) {
        try gpio.setLevel(pin, level);
    }
}

fn setAllPinModes(mode: gpio.Mode) !void {
    var pin: u8 = 0;
    while (pin < bcm2835.BoardInfo.NUM_GPIO_PINS) : (pin += 1) {
        std.log.info("Setting mode for pin {}", .{pin});
        try gpio.setMode(pin, mode);
    }
}
