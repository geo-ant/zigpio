test "Test Suite" {
    _ = @import("gpio.zig");
    _ = @import("bcm2835.zig");
    _ = @import("peripherals.zig");
    _ = @import("integration-tests/bcm2835.zig");
    _ = @import("integration-tests/mocks.zig");
}
