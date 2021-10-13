pub const peripherals = @import("peripherals.zig");



const std = @import("std");

/// a mock that pretends to give us a mapping
/// to the physical memory of the peripherals
pub const MockGpioMemoryMapper = struct {
    const Self = @This();

    /// the buffer used to provide the mock memory.
    /// This is allocated and deallocated in this buffer
    buffer: peripherals.GpioRegisterMemory,
    /// the memory mapper interface
    memory_mapper: peripherals.GpiomemMapper,
    /// the allocator so we can use it for deallocation
    allocator: *std.mem.Allocator,

    /// create a new mock that pretends it is mapping the given address range
    pub fn init(allocator: *std.mem.Allocator, addresses_to_emulate: peripherals.AddressRange) !Self {
        var initial =  Self{ .allocator = allocator,
         .memory_mapper = .{ .map_fn = mappedPhysicalMemoryImpl }, 
         .buffer = try allocator.allocWithOptions(peripherals.GpioRegister, try std.math.divExact(usize,addresses_to_emulate.len, @sizeOf(peripherals.GpioRegister)), 1, null)};
        // zero initialize the buffer
        for(initial.buffer) |*elem| {
            elem.* = 0;
        }
        return initial;
    }

    pub fn deinit(self : *Self) void {
        self.allocator.free(self.buffer);
    }

    fn mappedPhysicalMemoryImpl(interface: *peripherals.GpiomemMapper) !peripherals.GpioRegisterMemory {
        const self = @fieldParentPtr(Self, "memory_mapper", interface);
        return self.buffer;
    }
};
