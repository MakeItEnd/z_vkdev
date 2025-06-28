//! Queue family indices retreiver

pub const QueueFamilyIndices = struct {
    graphics_family: ?u32,

    pub fn find(
        allocator: std.mem.Allocator,
        instance: *const vk.InstanceProxy,
        device: vk.PhysicalDevice,
    ) !QueueFamilyIndices {
        var indices: QueueFamilyIndices = .{
            .graphics_family = null,
        };

        const props = try instance.getPhysicalDeviceQueueFamilyPropertiesAlloc(device, allocator);
        defer allocator.free(props);

        for (props, 0..) |prop, index| {
            if (prop.queue_flags.graphics_bit == true) {
                indices.graphics_family = @intCast(index);
            }
        }

        return indices;
    }

    pub fn isComplete(self: *const QueueFamilyIndices) bool {
        return self.graphics_family != null;
    }
};

const std = @import("std");
const vk = @import("vulkan");
