//! Vulkan bootstrap physical device picker.

pub const PhysicalDeviceSelector = struct {
    allocator: std.mem.Allocator,
    instance: *vk.InstanceProxy,
    surface: vk.SurfaceKHR,

    pub fn new(
        allocator: std.mem.Allocator,
        instance: *vk.InstanceProxy,
        surface: vk.SurfaceKHR,
    ) PhysicalDeviceSelector {
        return .{
            .allocator = allocator,
            .instance = instance,
            .surface = surface,
        };
    }

    pub fn pick(self: PhysicalDeviceSelector) !vk.PhysicalDevice {
        const physical_devices = try self.instance.enumeratePhysicalDevicesAlloc(self.allocator);
        defer self.allocator.free(physical_devices);

        if (physical_devices.len == 0) return error.noPhysicalDevicesAvailable;

        for (physical_devices) |physical_device| {
            if (try self.isDeviceSuitable(physical_device)) {
                return physical_device; // TODO: Check if the deallocation doesn't fuck this up
            }
        }

        return error.noSuitablePhysicalDeviceFound;
    }

    fn isDeviceSuitable(self: *const PhysicalDeviceSelector, physical_device: vk.PhysicalDevice) !bool {
        const Props = self.instance.getPhysicalDeviceProperties(physical_device);
        std.log.debug("Device Name: {s}", .{Props.device_name});

        const indices: QueueFamilyIndices = try QueueFamilyIndices.find(
            self.allocator,
            self.instance,
            physical_device,
            self.surface,
        );

        return self.checkFeatures(physical_device) and Props.device_type == .discrete_gpu and indices.isComplete();
    }

    /// Check if the physical devices meets the required features of the engine.
    fn checkFeatures(self: *const PhysicalDeviceSelector, physical_device: vk.PhysicalDevice) bool {
        var features14: vk.PhysicalDeviceVulkan14Features = .{};
        var features13: vk.PhysicalDeviceVulkan13Features = .{
            .p_next = &features14,
        };
        var features12: vk.PhysicalDeviceVulkan12Features = .{
            .p_next = &features13,
        };
        var features11: vk.PhysicalDeviceVulkan11Features = .{
            .p_next = &features12,
        };
        var features2: vk.PhysicalDeviceFeatures2 = .{
            .p_next = &features11,
            .features = vk.PhysicalDeviceFeatures{},
        };

        self.instance.getPhysicalDeviceFeatures2(physical_device, &features2);

        // ! KEEP THESE IN SYNC WITH THE LOGICAL DEVICE ONES.
        return features13.dynamic_rendering == vk.TRUE and
            features13.synchronization_2 == vk.TRUE and
            features12.buffer_device_address == vk.TRUE and
            features12.descriptor_indexing == vk.TRUE and
            features2.features.geometry_shader == vk.TRUE;
    }
};

const std = @import("std");
const sdl3 = @import("sdl3");
const vk = @import("vulkan");

const QueueFamilyIndices = @import("utils.zig").QueueFamilyIndices;
const requiredFeatures = @import("utils.zig").requiredFeatures;
