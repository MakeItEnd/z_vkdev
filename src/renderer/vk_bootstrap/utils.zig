//! Queue family indices retreiver

pub const QueueFamilyIndices = struct {
    graphics_family: ?u32 = null,
    present_family: ?u32 = null,

    pub fn find(
        allocator: std.mem.Allocator,
        instance: *const vk.InstanceProxy,
        device: vk.PhysicalDevice,
        surface: vk.SurfaceKHR,
    ) !QueueFamilyIndices {
        var self: QueueFamilyIndices = .{
            .graphics_family = null,
            .present_family = null,
        };

        const props = try instance.getPhysicalDeviceQueueFamilyPropertiesAlloc(device, allocator);
        defer allocator.free(props);

        for (props, 0..) |prop, index| {
            // std.log.debug("Prop {d} :: {any}", .{ index, prop.queue_flags });
            if (prop.queue_flags.graphics_bit == true) {
                self.graphics_family = @intCast(index);
            }

            if (try instance.getPhysicalDeviceSurfaceSupportKHR(
                device,
                @intCast(index),
                surface,
            ) == vk.TRUE) {
                self.present_family = @intCast(index);
            }

            if (self.graphics_family != null and self.present_family != null) {
                return self;
            }
        }

        return error.CouldNotFindAllRequestedQueues;
    }

    pub fn isComplete(self: *const QueueFamilyIndices) bool {
        return self.graphics_family != null;
    }
};

const std = @import("std");
const vk = @import("vulkan");
