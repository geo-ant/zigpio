const peripherals = @import("peripherals.zig");

const GpioRegisterInfo = peripherals.GpioRegisterInfo;

const std = @import("std");

/// A structure containin info about the BCM2835 chip
/// see this website which does a brilliant job of explaining everything
/// https://www.pieter-jan.com/node/15
/// The most important thing is to look at the BCM2835 peripheral manual (pi1 / p2)
/// and then see in section 1.2.3 how the register addresses in the manual relate with
/// the physical memory. Then see the Gpio section for an explanation of how to
/// operate the Gpio pins using the registers.
/// The primary source for all of this is the Broadcom BCM2835 ARM Peripherals Manual
/// In this structure I am assuming that dev/gpiomem is mapped, which we can map as 
/// 4 byte values (the width of the registers), so we don't really care about the actual
/// physical positiion in memory of the registers but we care about the relative offset
/// with respect to the start of dev/gpiomem, which is what I captured with the structure below
pub const BoardInfo = struct {
    /// function select registers
    pub const GPFSEL: GpioRegisterInfo = .{ .zero_offset = 0, .count = 6 };
    /// pin output setting
    pub const GPSET: GpioRegisterInfo = .{ .zero_offset = 7, .count = 2 };
    /// pin output clearing
    pub const GPCLR: GpioRegisterInfo = .{ .zero_offset = 10, .count = 2 };
    /// pin level
    pub const GPLEV: GpioRegisterInfo = .{ .zero_offset = 13, .count = 2 };
    /// edge detect status
    pub const GPEDS: GpioRegisterInfo = .{ .zero_offset = 16, .count = 2 };
    /// rising edge detect enable
    pub const GPREN: GpioRegisterInfo = .{ .zero_offset = 19, .count = 2 };
    /// falling edge detect enable
    pub const GPFEN: GpioRegisterInfo = .{ .zero_offset = 22, .count = 2 };
    /// high detect enable
    pub const GPHEN: GpioRegisterInfo = .{ .zero_offset = 25, .count = 2 };
    /// low detect enable
    pub const GPLEN: GpioRegisterInfo = .{ .zero_offset = 28, .count = 2 };
    /// async rising edgde enable
    pub const GPAREN: GpioRegisterInfo = .{ .zero_offset = 31, .count = 2 };
    /// async falling edge detect enable
    pub const GPAFEN: GpioRegisterInfo = .{ .zero_offset = 34, .count = 2 };
    /// pull up / down
    pub const GPPUD: GpioRegisterInfo = .{ .zero_offset = 37, .count = 1 };
    /// pull up / down clock
    pub const GPPUDCLK: GpioRegisterInfo = .{ .zero_offset = 38, .count = 2 };
    
    /// the number of GPIO pins. Pin indices start at 0.
    pub const NUM_GPIO_PINS = 53;

    /// number of 4 byte GPIO registers. Not all of them are actually useful registers, because some are reserved
    pub const NUM_GPIO_REGISTERS = 41;
};

pub const Bcm2385GpioMemoryMapper = struct {
    const Self: type = @This();

    /// the GpioMemMapper interface
    memory_mapper: peripherals.GpioMemMapper,
    /// the raw bytes representing the memory mapping
    devgpiomem: []align(std.mem.page_size) u8,

    pub fn init() !Self {
        const devgpiomem = try std.fs.openFileAbsolute("/dev/gpiomem", std.fs.File.OpenFlags{ .read = true, .write = true });
        defer devgpiomem.close();

        return Self{ .devgpiomem = try std.os.mmap(null, BoardInfo.gpio_registers.len, std.os.PROT.READ | std.os.PROT.WRITE, std.os.MAP.SHARED, devgpiomem.handle, 0), .memory_mapper = .{ .map_fn = Self.memoryMap } };
    }

    /// unmap the mapped memory
    pub fn deinit(self: Self) void {
        std.os.munmap(self.devgpiomem);
    }

    pub fn memoryMap(interface: *peripherals.GpioMemMapper) !peripherals.GpioRegisterMemory {
        var self = @fieldParentPtr(Self, "memory_mapper", interface);
        return std.mem.bytesAsSlice(u32, self.devgpiomem);
    }
};
