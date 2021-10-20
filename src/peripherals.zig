pub const GpioRegister :type = u32;
pub const GpioRegisterMemory : type = []volatile align(1) GpioRegister;

/// an interface that gives us a mapping of the physical memory of the 
/// peripherals
pub const GpioMemMapper = struct {
    /// pointer to the actual function that provides a mapping of the memory
    map_fn : fn(*GpioMemMapper) anyerror!GpioRegisterMemory,

    /// the convenience function with which to use the interface
    /// provides access to a mapping of the GPIO registers
    pub fn memoryMap(interface : *GpioMemMapper) !GpioRegisterMemory {
        return interface.map_fn(interface);
    }
};

/// A physical adress starting at `start` with a length of `len` bytes
pub const AddressRange = struct { start: usize, len: usize };
