const std = @import("std");

const bcm2835 = @import("bcm2835.zig");

const mocks = @import("mocks.zig");

const gpio = @import("gpio.zig");

pub fn main() anyerror!void {

    // var gpalloc = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _= gpalloc.deinit();

    // var mock_mem = try mocks.MockGpioMemoryMapper.init(&gpalloc.allocator,bcm2835.BoardInfo.gpio_registers);
    // defer mock_mem.deinit();

    // std.log.info("All your codebase are belong to us.{}, {}", .{bcm2835.BoardInfo.peripheral_addresses.start, 0b100011});

    // _ = try bcm2835.Bcm2385GpioMemoryMapper.init();

    // std.log.info("sizeof u3 = {}, bitsizeof u3 = {}", .{@sizeOf(u3),@bitSizeOf(gpio.Mode)});

    // try gpio.init(&mock_mem.memory_mapper);
    // try gpio.setLevel(2,gpio.Level.High);
    // try gpio.setMode(12, gpio.Mode.Alternate0);
    // _ = try gpio.getLevel(2); // in mock mode this of course will not display High because the level is read in a different register!

    var mapper = try bcm2835.Bcm2385GpioMemoryMapper.init();
    defer mapper.deinit();
    
    try gpio.init(&mapper.memory_mapper);

    //try setAllPinModes(.Output);
    const pin_number = 3;
    try gpio.setMode(pin_number, gpio.Mode.Output);

    var idx :u32 = 0;
    while (idx < 100) : (idx+=1) {
        std.log.info("idx {}", .{idx});
        std.log.info("set pin to high",.{});
        try gpio.setLevel(pin_number,.High);
        std.time.sleep(500000000); //500ms
        std.log.info("set pin to low",.{});
        try gpio.setLevel(pin_number,.Low);
        std.time.sleep(500000000); //500ms
    }
}

fn setAllPinLevels(level: gpio.Level) !void {
    var pin :u8 = 0;
    while (pin < bcm2835.BoardInfo.NUM_GPIO_PINS) : (pin += 1) {
        try gpio.setLevel(pin, level); 
    }
}

fn setAllPinModes(mode: gpio.Mode) !void {
    var pin :u8 = 0;
    while (pin < bcm2835.BoardInfo.NUM_GPIO_PINS) : (pin += 1) {
        std.log.info("Setting mode for pin {}", .{pin});
        try gpio.setMode(pin, mode); 
    }
}