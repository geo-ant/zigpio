
const std = @import("std");
const bcm2835 = @import("../bcm2835.zig");
const gpio = @import("../gpio.zig");
const mocks = @import("mocks.zig");


const testing = std.testing;


test "SetLevel - High" {
    std.testing.log_level = .debug;
    var allocator = testing.allocator;
    var gpiomem = try mocks.MockGpioMemoryMapper.init(allocator,bcm2835.BoardInfo.gpio_registers);
    defer gpiomem.deinit();
    
    try gpio.init(&gpiomem.memory_mapper);
    defer gpio.deinit();

    // we can set the level to high without having to worry about setting the pin to the right mode
    // becasue we are just interested in the correct value being written into the right register
    try gpio.setLevel(4, .High);
    std.debug.print("register = 0b{b}\n", .{gpiomem.value_at(7)});

}
