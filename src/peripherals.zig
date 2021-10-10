/// an interface that gives us a mapping of the physical memory of the 
/// peripherals
pub const MemoryMapper = struct {
    /// pointer to the actual function that provides a mapping of the memory
    map_fn : fn(*MemoryMapper) anyerror![]u8,

    /// the convenience function with which to use the interface
    pub fn mappedPhysicalMemory(interface : *MemoryMapper) ![]u8 {
        return interface.physicalMemoryFn(interface);
    }
};

/// A physical adress starting at `start` with a length of `len` bytes
pub const AddressRange = struct { start: usize, len: usize };
