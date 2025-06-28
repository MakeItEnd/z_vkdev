//! Vulkan bootstrap methods to simplify the initialization process.

pub const InstanceBuilder = @import("./vk_bootstrap/instance_builder.zig").InstanceBuilder;
pub const PhysicalDeviceSelector = @import("./vk_bootstrap/physical_device_builder.zig").PhysicalDeviceSelector;
pub const QueueFamilyIndices = @import("./vk_bootstrap/queue_family_indices.zig").QueueFamilyIndices;
pub const DeviceBuilder = @import("./vk_bootstrap/device_builder.zig").DeviceBuilder;
