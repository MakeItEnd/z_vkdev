pub fn transition(
    image: vk.Image,
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
        .image = image,
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

pub fn copy(
    vk_ctx: *VK_CTX,
    cmd: vk.CommandBuffer,
    source: vk.Image,
    source_size: vk.Extent2D,
    destination: vk.Image,
    destination_size: vk.Extent2D,
) void {
    const blit_region: vk.ImageBlit2 = .{
        .src_subresource = .{
            .aspect_mask = .{
                .color_bit = true,
            },
            .mip_level = 0,
            .base_array_layer = 0,
            .layer_count = 1,
        },
        .src_offsets = .{
            .{
                .x = 0,
                .y = 0,
                .z = 0,
            },
            .{
                .x = @intCast(source_size.width),
                .y = @intCast(source_size.height),
                .z = 1,
            },
        },
        .dst_subresource = .{
            .aspect_mask = .{
                .color_bit = true,
            },
            .mip_level = 0,
            .base_array_layer = 0,
            .layer_count = 1,
        },
        .dst_offsets = .{
            .{
                .x = 0,
                .y = 0,
                .z = 0,
            },
            .{
                .x = @intCast(destination_size.width),
                .y = @intCast(destination_size.height),
                .z = 1,
            },
        },
    };

    const blit_info: vk.BlitImageInfo2 = .{
        .src_image = source,
        .src_image_layout = .transfer_src_optimal,
        .dst_image = destination,
        .dst_image_layout = .transfer_dst_optimal,
        .region_count = 1,
        .p_regions = @ptrCast(&blit_region),
        .filter = .linear,
    };

    vk_ctx.device.cmdBlitImage2(cmd, &blit_info);
}

const vk = @import("vulkan");
const VK_CTX = @import("./vk_ctx.zig").VK_CTX;
const vk_init = @import("./vk_initializers.zig");
