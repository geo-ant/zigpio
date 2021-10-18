const std = @import("std");
const bcm2835 = @import("../bcm2835.zig");
const gpio = @import("../gpio.zig");
const mocks = @import("mocks.zig");
const peripherals = @import("../peripherals.zig");

test "SetLevel - High" {
    std.testing.log_level = .debug;
    var allocator = std.testing.allocator;
    var gpiomem = try mocks.MockGpioMemoryMapper.init(allocator, bcm2835.BoardInfo.gpio_registers);
    defer gpiomem.deinit();

    try gpio.init(&gpiomem.memory_mapper);
    defer gpio.deinit();

    // we can set the level to high without having to worry about setting the pin to the right mode
    // because we are just interested in the correct value being written into the right register
    // but before we do, verify that the gpset registers indeed hold only null values
    try std.testing.expectEqual(gpiomem.registerValue(7), 0);
    try std.testing.expectEqual(gpiomem.registerValue(8), 0);

    try gpio.setLevel(0, .High);
    try std.testing.expectEqual(gpiomem.registerValue(7), 0b1);
    try gpio.setLevel(1, .High);
    try std.testing.expectEqual(gpiomem.registerValue(7), 0b11);
    try gpio.setLevel(10, .High);
    try std.testing.expectEqual(gpiomem.registerValue(7), 0b10000000011);
    try gpio.setLevel(42, .High);
    try std.testing.expectEqual(gpiomem.registerValue(7), 0b10000000011);
    try std.testing.expectEqual(gpiomem.registerValue(8), 0b10000000000);
}

test "SetLevel - Low" {
    std.testing.log_level = .debug;
    var allocator = std.testing.allocator;
    var gpiomem = try mocks.MockGpioMemoryMapper.init(allocator, bcm2835.BoardInfo.gpio_registers);
    defer gpiomem.deinit();

    try gpio.init(&gpiomem.memory_mapper);
    defer gpio.deinit();

    try std.testing.expectEqual(gpiomem.registerValue(10), 0);
    try std.testing.expectEqual(gpiomem.registerValue(11), 0);

    try gpio.setLevel(0, .Low);
    try std.testing.expectEqual(gpiomem.registerValue(10), 0b1);
    try gpio.setLevel(1, .Low);
    try std.testing.expectEqual(gpiomem.registerValue(10), 0b11);
    try gpio.setLevel(10, .Low);
    try std.testing.expectEqual(gpiomem.registerValue(10), 0b10000000011);
    try gpio.setLevel(42, .Low);
    try std.testing.expectEqual(gpiomem.registerValue(10), 0b10000000011);
    try std.testing.expectEqual(gpiomem.registerValue(11), 0b10000000000);
}

test "GetLevel" {
    std.testing.log_level = .debug;
    var allocator = std.testing.allocator;
    var gpiomem = try mocks.MockGpioMemoryMapper.init(allocator, bcm2835.BoardInfo.gpio_registers);
    defer gpiomem.deinit();

    try gpio.init(&gpiomem.memory_mapper);
    defer gpio.deinit();

    const gplev0 = 0b1001001; //pins high: (0,3,6)
    const gplev1 = 0b0110110; //pins high: 32 + (1,2,4,5)

    try gpiomem.setRegisterValue(13, gplev0);
    try gpiomem.setRegisterValue(14, gplev1);

    try std.testing.expectEqual(gpio.getLevel(0), .High);
    try std.testing.expectEqual(gpio.getLevel(1), .Low);
    try std.testing.expectEqual(gpio.getLevel(2), .Low);
    try std.testing.expectEqual(gpio.getLevel(3), .High);
    try std.testing.expectEqual(gpio.getLevel(4), .Low);
    try std.testing.expectEqual(gpio.getLevel(5), .Low);
    try std.testing.expectEqual(gpio.getLevel(6), .High);
    try std.testing.expectEqual(gpio.getLevel(32 + 0), .Low);
    try std.testing.expectEqual(gpio.getLevel(32 + 1), .High);
    try std.testing.expectEqual(gpio.getLevel(32 + 2), .High);
    try std.testing.expectEqual(gpio.getLevel(32 + 3), .Low);
    try std.testing.expectEqual(gpio.getLevel(32 + 4), .High);
    try std.testing.expectEqual(gpio.getLevel(32 + 5), .High);
    try std.testing.expectEqual(gpio.getLevel(32 + 6), .Low);
}

test "SetMode" {
    try std.testing.expect(false);
}
