pub const peripherals = @import("peripherals.zig");

const std = @import("std");

/// a mock that pretends to give us a mapping
/// to the physical memory of the peripherals
pub const MockPeripheralMemoryMapper = struct {
    const Self = @This();

    /// the buffer used to mock the memory
    buffer : []u8,
    memory_mapper : peripherals.MemoryMapper,

    /// create a new mock that pretends it is mapping the given address range
    pub fn init(allocator : *std.mem.Allocator, addresses_to_emulate : peripherals.AddressRange) !Self {
        return Self {
            .memory_mapper = .
            {.map_fn = mappedPhysicalMemoryImpl},
            .buffer = try allocator.alloc(u8, addresses_to_emulate.len)
        };
    }

    pub fn mappedPhysicalMemoryImpl(interface : *peripherals.MemoryMapper) ![]u8 {
        const self = @fieldParentPtr(Self, "memory_mapper", interface);
        return self.buffer;
    }


};