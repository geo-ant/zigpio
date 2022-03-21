pub const GpioRegister = u32;
pub const GpioRegisterSlice = []align(1) volatile GpioRegister;

/// Information about where a given register can be found in gpiomem
/// this assumes all registers have the same byte width of 4 bytes
pub const GpioRegisterInfo = struct {
    /// the index where the 0-th register of that type can be found
    zero_offset: usize,
    /// the number of registers of this type (expected to be layed out contiguously in memory)
    count: usize,
};

/// an interface that gives us a mapping of the physical memory of the 
/// peripherals
pub const GpioMemInterface = struct {
    /// pointer to the actual function that provides a mapping of the memory
    map_fn: fn (*GpioMemInterface) anyerror!GpioRegisterSlice,

    /// the convenience function with which to use the interface
    /// provides access to a mapping of the GPIO registers
    pub fn memoryMap(interface: *GpioMemInterface) !GpioRegisterSlice {
        return interface.map_fn(interface);
    }
};
