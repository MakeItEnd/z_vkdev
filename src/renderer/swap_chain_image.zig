//! Swap chain image

pub const SwapChainImage = struct {
    handle: vk.Image,
    view: vk.ImageView,
    image_acquired: vk.Semaphore,
    render_finished: vk.Semaphore,
    frame_fence: vk.Fence,

    pub fn init(vk_ctx: *const VK_CTX, image: vk.Image, format: vk.Format) !SwapChainImage {
        const view = try vk_ctx.device.createImageView(&.{
            .image = image,
            .view_type = .@"2d",
            .format = format,
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        }, null);
        errdefer vk_ctx.device.destroyImageView(view, null);

        const image_acquired = try vk_ctx.device.createSemaphore(&.{}, null);
        errdefer vk_ctx.device.destroySemaphore(image_acquired, null);

        const render_finished = try vk_ctx.device.createSemaphore(&.{}, null);
        errdefer vk_ctx.device.destroySemaphore(render_finished, null);

        const frame_fence = try vk_ctx.device.createFence(&.{ .flags = .{ .signaled_bit = true } }, null);
        errdefer vk_ctx.device.destroyFence(frame_fence, null);

        return SwapChainImage{
            .handle = image,
            .view = view,
            .image_acquired = image_acquired,
            .render_finished = render_finished,
            .frame_fence = frame_fence,
        };
    }

    pub fn deinit(self: SwapChainImage, vk_ctx: *const VK_CTX) void {
        self.waitForFence(vk_ctx) catch return;

        vk_ctx.device.destroyImageView(self.view, null);
        vk_ctx.device.destroySemaphore(self.image_acquired, null);
        vk_ctx.device.destroySemaphore(self.render_finished, null);
        vk_ctx.device.destroyFence(self.frame_fence, null);
    }

    pub fn transition(
        self: *SwapChainImage,
        vk_ctx: *VK_CTX,
        cmd: vk.CommandBuffer,
        current_layout: vk.ImageLayout,
        new_layout: vk.ImageLayout,
    ) void {
        const aspect_mask: vk.ImageAspectFlags = if (new_layout == vk.ImageLayout.depth_attachment_optimal)
            .{ .depth_bit = true }
        else
            .{ .color_bit = true };

        const image_barrier: vk.ImageMemoryBarrier2 = .{
            .src_stage_mask = .{
                .all_commands_bit = true,
            },
            .src_access_mask = .{
                .memory_write_bit = true,
            },
            .dst_stage_mask = .{
                .all_commands_bit = true,
            },
            .dst_access_mask = .{
                .host_write_bit = true,
                .memory_read_bit = true,
            },
            .old_layout = current_layout,
            .new_layout = new_layout,
            .image = self.handle,
            .subresource_range = vk_init.image_subresource_range(aspect_mask),
            .src_queue_family_index = 0,
            .dst_queue_family_index = 0,
        };

        const dependency_info: vk.DependencyInfo = .{
            .image_memory_barrier_count = 1,
            .p_image_memory_barriers = @ptrCast(&image_barrier),
        };

        vk_ctx.device.cmdPipelineBarrier2(
            cmd,
            &dependency_info,
        );
    }

    fn waitForFence(self: SwapChainImage, vk_ctx: *const VK_CTX) !void {
        _ = try vk_ctx.device.waitForFences(
            1,
            @ptrCast(&self.frame_fence),
            vk.TRUE,
            std.math.maxInt(u64),
        );
    }
};

const std = @import("std");
const vk = @import("vulkan");
const VK_CTX = @import("./vk_ctx.zig").VK_CTX;
const vk_init = @import("./vk_initializers.zig");
