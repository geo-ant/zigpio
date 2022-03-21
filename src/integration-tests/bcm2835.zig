const std = @import("std");
const bcm2835 = @import("../bcm2835.zig");
const gpio = @import("../gpio.zig");
const mocks = @import("mocks.zig");
const peripherals = @import("../peripherals.zig");

test "SetLevel - High" {
    std.testing.log_level = .debug;
    var allocator = std.testing.allocator;
    var gpiomem = try mocks.MockGpioMemoryMapper.init(&allocator, bcm2835.BoardInfo.NUM_GPIO_REGISTERS);
    defer gpiomem.deinit();

    try gpio.init(&gpiomem.memory_mapper);
    defer gpio.deinit();

    // we can set the level to high without having to worry about setting the pin to the right mode
    // because we are just interested in the correct value being written into the right register
    // but before we do, verify that the gpset registers indeed hold only null values
    try std.testing.expectEqual(gpiomem.registerValue(7), 0); //gpset0
    try std.testing.expectEqual(gpiomem.registerValue(8), 0); //gpset1

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
    var gpiomem = try mocks.MockGpioMemoryMapper.init(&allocator, bcm2835.BoardInfo.NUM_GPIO_REGISTERS);
    defer gpiomem.deinit();

    try gpio.init(&gpiomem.memory_mapper);
    defer gpio.deinit();

    try std.testing.expectEqual(gpiomem.registerValue(10), 0); //gpclr0
    try std.testing.expectEqual(gpiomem.registerValue(11), 0); //gpclr1

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
    var gpiomem = try mocks.MockGpioMemoryMapper.init(&allocator, bcm2835.BoardInfo.NUM_GPIO_REGISTERS);
    defer gpiomem.deinit();

    try gpio.init(&gpiomem.memory_mapper);
    defer gpio.deinit();

    const gplev0 = 0b1001001; //pins high: (0,3,6)
    const gplev1 = 0b0110110; //pins high: 32 + (1,2,4,5)

    try gpiomem.setRegisterValue(13, gplev0); //gplev0
    try gpiomem.setRegisterValue(14, gplev1); //gplev1

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
    std.testing.log_level = .debug;
    var allocator = std.testing.allocator;
    var gpiomem = try mocks.MockGpioMemoryMapper.init(&allocator, bcm2835.BoardInfo.NUM_GPIO_REGISTERS);
    defer gpiomem.deinit();

    try gpio.init(&gpiomem.memory_mapper);
    defer gpio.deinit();

    try std.testing.expectEqual(gpiomem.registerValue(0), 0); //gpfsel0
    try std.testing.expectEqual(gpiomem.registerValue(1), 0); //gpfsel1
    try std.testing.expectEqual(gpiomem.registerValue(5), 0); //gpfsel5

    try gpio.setMode(0, .Input);
    try std.testing.expectEqual(gpiomem.registerValue(0), 0b0);
    try gpio.setMode(1, .Output);
    try std.testing.expectEqual(gpiomem.registerValue(0), 0b001000);
    try gpio.setMode(11, .Alternate1);
    try std.testing.expectEqual(gpiomem.registerValue(1), 0b101000);
    try gpio.setMode(50, .Alternate1);
    try std.testing.expectEqual(gpiomem.registerValue(5), 0b101);
}

test "GetMode" {
    std.testing.log_level = .debug;
    var allocator = std.testing.allocator;
    var gpiomem = try mocks.MockGpioMemoryMapper.init(&allocator, bcm2835.BoardInfo.NUM_GPIO_REGISTERS);
    defer gpiomem.deinit();

    try gpio.init(&gpiomem.memory_mapper);
    defer gpio.deinit();

    try gpiomem.setRegisterValue(0, 0b00010000000000000000000000000101); //gpfsel 0
    try gpiomem.setRegisterValue(1, 0b00000111000000000000000000011000); //gpfsel 1

    try std.testing.expectEqual(gpio.Mode.Alternate1, try gpio.getMode(0));
    try std.testing.expectEqual(gpio.Mode.Input, try gpio.getMode(1));
    try std.testing.expectEqual(gpio.Mode.Alternate5, try gpio.getMode(9));
    try std.testing.expectEqual(gpio.Mode.Input, try gpio.getMode(10));
    try std.testing.expectEqual(gpio.Mode.Alternate4, try gpio.getMode(11));
    try std.testing.expectEqual(gpio.Mode.Input, try gpio.getMode(12));
    try std.testing.expectEqual(gpio.Mode.Input, try gpio.getMode(17));
    try std.testing.expectEqual(gpio.Mode.Alternate3, try gpio.getMode(18));
}

test "setPull" {
    std.testing.log_level = .debug;
    var allocator = std.testing.allocator;
    var gpiomem = try mocks.MockGpioMemoryMapper.init(&allocator, bcm2835.BoardInfo.NUM_GPIO_REGISTERS);
    defer gpiomem.deinit();

    try gpio.init(&gpiomem.memory_mapper);
    defer gpio.deinit();
    // unfortunately we can just smoke test this one here, because the register values
    // will be set and unset in this function.
    try gpio.setPull(2, .PullDown);
}

test "setDetectionMode" {
    std.testing.log_level = .debug;
    var allocator = std.testing.allocator;
    var gpiomem = try mocks.MockGpioMemoryMapper.init(&allocator, bcm2835.BoardInfo.NUM_GPIO_REGISTERS);
    defer gpiomem.deinit();

    try gpio.init(&gpiomem.memory_mapper);
    defer gpio.deinit();

    // enable all detections for pin 0
    try gpio.setDetectionMode(0, .{ .high = true, .low = true, .rising = true, .falling = true });
    try std.testing.expectEqual(@as(u32, 0b1), gpiomem.registerValue(19));
    try std.testing.expectEqual(@as(u32, 0b1), gpiomem.registerValue(22));
    try std.testing.expectEqual(@as(u32, 0b1), gpiomem.registerValue(25));
    try std.testing.expectEqual(@as(u32, 0b1), gpiomem.registerValue(28));

    // disable some detections for pin 0, but leave others untouched
    try gpio.setDetectionMode(0,.{.rising = false, .falling = false});
    try std.testing.expectEqual(@as(u32, 0b0), gpiomem.registerValue(19));
    try std.testing.expectEqual(@as(u32, 0b0), gpiomem.registerValue(22));
    try std.testing.expectEqual(@as(u32, 0b1), gpiomem.registerValue(25));
    try std.testing.expectEqual(@as(u32, 0b1), gpiomem.registerValue(28));

    // enable some things on a different register
    try gpio.setDetectionMode(32+1, .{ .high = true, .low = true} );
    try std.testing.expectEqual(@as(u32, 0), gpiomem.registerValue(20));
    try std.testing.expectEqual(@as(u32, 0), gpiomem.registerValue(23));
    try std.testing.expectEqual(@as(u32, 0b10), gpiomem.registerValue(26));
    try std.testing.expectEqual(@as(u32, 0b10), gpiomem.registerValue(29));
}
