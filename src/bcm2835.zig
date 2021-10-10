pub const peripherals = @import("peripherals.zig");

const AddressRange = peripherals.AddressRange;

/// A structure containin info about the BCM2835 chip
pub const Bcm2835Info = struct {
    /// the *physical* address space of all peripherals
    pub const peripheral_addresses: AddressRange = .{ .start = 0x20000000, .len = 0xFFFFFF };
    /// physical address space of the gpio registers GPFSEL{n} (function select)
    pub const gpfsel_registers: AddressRange = .{ .start = peripheral_addresses.start + 0x200000, .len = 6*4};
    /// physical address space of the gpio registers GPSET{n} (output setting)
    pub const gpset_registers : AddressRange = .{.start = gpfsel_registers.start + 0x1C , .len = 2*4};
    /// physical address space of the gpio registers GPCLR{n} (clearing pin output)
    pub const gpclr_registers : AddressRange = .{.start = gpfsel_registers.start + 0x28 , .len = 2*4};
    // /// physical address space of the gpio registers GPLEV{n} (reading pin levels)
};

pub const Bcm2835GpioMemoryMapping = struct {
    /// slice pointing to the physical mem location of the gpio registers
    gpio_physical_memory : []u8,
    memory_interface : peripherals.MemoryMapper,

    const Self = @This();

    pub fn init() Self{
        
    }

    pub fn physicalMemoryMap() ![]u8 {
        return "test test";
    }
};