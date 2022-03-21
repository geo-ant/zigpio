pub const peripherals = @import("../peripherals.zig");

const std = @import("std");

/// a mock that pretends to give us a mapping
/// to the physical memory of the peripherals
pub const MockGpioMemoryMapper = struct {
    const Self = @This();

    /// the buffer used to provide the mock memory.
    /// This is allocated and deallocated in this buffer
    registers: peripherals.GpioRegisterSlice,
    /// the memory mapper interface
    memory_mapper: peripherals.GpioMemInterface,
    /// the allocator so we can use it for deallocation
    allocator: *std.mem.Allocator,

    /// create a new mock that pretends it is mapping the given address range
    pub fn init(allocator: *std.mem.Allocator, gpio_register_count : usize) !Self {
        var initial = Self{ .allocator = allocator, .memory_mapper = .{ .map_fn = mappedPhysicalMemoryImpl }, .registers = try allocator.allocWithOptions(peripherals.GpioRegister, gpio_register_count, 1, null) };
        // zero initialize the buffer
        for (initial.registers) |*elem| {
            elem.* = 0;
        }
        return initial;
    }

    /// free the allocated memory
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.registers);
    }

    /// get the value of the register at the given index
    pub fn registerValue(self: Self, register_index: usize) peripherals.GpioRegister {
        return self.registers[register_index];
    }

    pub fn setRegisterValue(self: *Self, register_index: usize, value: peripherals.GpioRegister) !void {
        if (register_index < self.registers.len) {
            self.registers[register_index] = value;
        } else {
            return error.OutOfBounds;
        }
    }

    fn mappedPhysicalMemoryImpl(interface: *peripherals.GpioMemInterface) !peripherals.GpioRegisterSlice {
        const self = @fieldParentPtr(Self, "memory_mapper", interface);
        return self.registers;
    }
};
