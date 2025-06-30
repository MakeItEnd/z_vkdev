//! Vulkan bootstrap logical device builder.

pub const DeviceBuilder = struct {
    allocator: std.mem.Allocator,
    instance: *vk.InstanceProxy,
    physical_device: vk.PhysicalDevice,
    queue_family_indices: QueueFamilyIndices,

    pub fn new(
        allocator: std.mem.Allocator,
        instance: *vk.InstanceProxy,
        physical_device: vk.PhysicalDevice,
        surface: vk.SurfaceKHR,
    ) DeviceBuilder {
        const queue_family_indices: QueueFamilyIndices = QueueFamilyIndices.find(
            allocator,
            instance,
            physical_device,
            surface,
        ) catch QueueFamilyIndices{};

        return .{
            .allocator = allocator,
            .instance = instance,
            .physical_device = physical_device,
            .queue_family_indices = queue_family_indices,
        };
    }

    // ! Make a function to set features2 in PhysicalDevicePicker and use it here.
    pub fn build(self: DeviceBuilder) !vk.DeviceProxy {
        const queue_priority = [_]f32{1.0};
        const qci = [_]vk.DeviceQueueCreateInfo{
            .{
                .queue_family_index = self.queue_family_indices.graphics_family.?,
                .queue_count = 1,
                .p_queue_priorities = &queue_priority,
            },
            // .{
            //     .queue_family_index = self.queue_family_indices.present_family,
            //     .queue_count = 1,
            //     .p_queue_priorities = &queue_priority,
            // },
        };

        // ! KEEP THESE IN SYNC WITH THE PHYSICAL DEVICE ONES.
        var features14: vk.PhysicalDeviceVulkan14Features = .{};
        var features13: vk.PhysicalDeviceVulkan13Features = .{
            .dynamic_rendering = vk.TRUE,
            .synchronization_2 = vk.TRUE,
            .p_next = &features14,
        };
        var features12: vk.PhysicalDeviceVulkan12Features = .{
            .buffer_device_address = vk.TRUE,
            .descriptor_indexing = vk.TRUE,
            .p_next = &features13,
        };
        var features11: vk.PhysicalDeviceVulkan11Features = .{
            .p_next = &features12,
        };
        var features2: vk.PhysicalDeviceFeatures2 = .{
            .p_next = &features11,
            .features = vk.PhysicalDeviceFeatures{},
        };

        const required_device_extensions = [_][:0]const u8{
            vk.extensions.khr_swapchain.name,
        };

        const dev = try self.instance.createDevice(self.physical_device, &.{
            .queue_create_info_count = qci.len,
            .p_queue_create_infos = &qci,
            .enabled_extension_count = required_device_extensions.len,
            .pp_enabled_extension_names = @ptrCast(&required_device_extensions),
            .p_next = &features2,
        }, null);

        const vkd = try self.allocator.create(vk.DeviceWrapper);
        errdefer self.allocator.destroy(vkd);
        vkd.* = vk.DeviceWrapper.load(dev, self.instance.wrapper.dispatch.vkGetDeviceProcAddr.?);
        const device: vk.DeviceProxy = vk.DeviceProxy.init(dev, vkd);
        errdefer device.destroyDevice(null);

        return device;
    }
};

const std = @import("std");
const sdl3 = @import("sdl3");
const vk = @import("vulkan");

const QueueFamilyIndices = @import("./utils.zig").QueueFamilyIndices;
