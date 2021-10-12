const std = @import("std");

const bcm2835 = @import("bcm2835.zig");

const mocks = @import("mocks.zig");

const gpio = @import("gpio.zig");

pub fn main() anyerror!void {

    var gpalloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer _= gpalloc.deinit();

    var mock_mem = try mocks.MockGpioMemoryMapper.init(&gpalloc.allocator,bcm2835.Bcm2835Info.gpio_registers);
    defer mock_mem.deinit();

    var arr  = [_]u8{1,2,3};
    var ptr :  []volatile u8 = arr[0..2];
    std.log.info("All your codebase are belong to us.{}, {}", .{bcm2835.Bcm2835Info.peripheral_addresses.start, 0b100011});

    _ = ptr;
    _ = arr;

    try gpio.init(&mock_mem.memory_mapper);
    
}
