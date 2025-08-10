//! A module that holds default initializations methods for vulkan functionality
//! to cut down on the boilerplate.

pub fn command_pool_create_info(queueFamilyIndex: u32, flags: ?vk.CommandPoolCreateFlags) vk.CommandPoolCreateInfo {
    return .{
        .queueFamilyIndex = queueFamilyIndex,
        .flags = flags orelse .{},
    };
}

pub fn command_buffer_allocate_info(pool: vk.CommandPool, count: ?u32) vk.CommandBufferAllocateInfo {
    return .{
        .command_pool = pool,
        .command_buffer_count = count orelse 1,
        .level = .primary,
    };
}

pub fn command_buffer_begin_info(flags: ?vk.CommandBufferUsageFlags) vk.CommandBufferBeginInfo {
    return .{
        .flags = flags orelse .{},
    };
}

pub fn command_buffer_submit_info(cmd: vk.CommandBuffer) vk.CommandBufferSubmitInfo {
    return .{
        .command_buffe = cmd,
        .device_mask = 0,
    };
}

pub fn fence_create_info(flags: ?vk.FenceCreateFlags) vk.FenceCreateInfo {
    return .{
        .flags = flags orelse .{},
    };
}

pub fn semaphore_create_info(flags: ?vk.SemaphoreCreateFlags) vk.SemaphoreCreateInfo {
    return .{
        .flags = flags orelse .{},
    };
}

pub fn submit_info(
    cmd: *const vk.CommandBufferSubmitInfo,
    signalSemaphoreInfo: ?*vk.SemaphoreSubmitInfo,
    waitSemaphoreInfo: ?*vk.SemaphoreSubmitInfo,
) vk.SubmitInfo2 {
    return .{
        .wait_semaphore_info_count = if (waitSemaphoreInfo) |_| 1 else 0,
        .p_wait_semaphore_infos = @ptrCast(waitSemaphoreInfo),
        .command_buffer_info_count = 1,
        .p_command_buffer_infos = @ptrCast(cmd),
        .signal_semaphore_info_count = if (signalSemaphoreInfo) |_| 1 else 0,
        .p_signal_semaphore_infos = @ptrCast(signalSemaphoreInfo),
    };
}

pub fn present_info() vk.PresentInfoKHR {
    return .{
        .wait_semaphore_count = 0,
        .p_wait_semaphores = null,
        .swapchain_count = 0,
        .p_swapchains = .{},
        .p_image_indices = .{},
        .p_results = null,
    };
}

// VkRenderingAttachmentInfo vkinit_attachment_info(VkImageView view, VkClearValue* clear, VkImageLayout layout /*= VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL*/);
pub fn attachment_info(
    view: vk.ImageView,
    clear: ?*vk.ClearValue,
    layout: ?vk.ImageLayout,
) vk.RenderingAttachmentInfo {
    return .{
        .image_view = view,
        .image_layout = layout orelse .color_attachment_optimal,
        .load_op = if (clear) |_| .clear else .load,
        .store_op = .store,
        .resolve_mode = .{},
        .resolve_image_layout = .undefined,
        .clear_value = if (clear) |c| c.* else .{
            .color = .{
                .float_32 = [4]f32{
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                },
            },
        },
    };
}

pub fn depth_attachment_info(
    view: vk.ImageView,
    layout: vk.ImageLayout, // Default: .color_attachment_optimal
) vk.RenderingAttachmentInfo {
    return .{
        .image_view = view,
        .image_layout = layout,
        .resolve_mode = .null_handle,
        .resolve_image_layout = .null_handle,
        .load_op = .clear,
        .store_op = .store,
        .clear_value = .{
            .depth_stencil = .{
                .depth = 0.0,
                .stencil = 0,
            },
        },
    };
}

pub fn rendering_info(
    renderExtent: vk.Extent2D,
    colorAttachment: *vk.RenderingAttachmentInfo,
    depthAttachment: ?*vk.RenderingAttachmentInfo,
) vk.RenderingInfo {
    return .{
        .flags = .{},
        .render_area = .{
            .offset = .{
                .x = 0,
                .y = 0,
            },
            .extent = renderExtent,
        },
        .layer_count = 1,
        .view_mask = 0,
        .color_attachment_count = 1,
        .p_color_attachments = @ptrCast(colorAttachment),
        .p_depth_attachment = depthAttachment,
        .p_stencil_attachment = null,
    };
}

pub fn image_subresource_range(aspectMask: vk.ImageAspectFlags) vk.ImageSubresourceRange {
    return .{
        .aspect_mask = aspectMask,
        .base_mip_level = 0,
        .level_count = vk.REMAINING_MIP_LEVELS,
        .base_array_layer = 0,
        .layer_count = vk.REMAINING_ARRAY_LAYERS,
    };
}

pub fn semaphore_submit_info(stageMask: vk.PipelineStageFlags2, semaphore: vk.Semaphore) vk.SemaphoreSubmitInfo {
    return .{
        .semaphore = semaphore,
        .value = 1,
        .stage_mask = stageMask,
        .device_index = 0,
    };
}

pub fn descriptorset_layout_binding(
    descriptor_type: vk.DescriptorType,
    stageFlags: vk.ShaderStageFlags,
    binding: u32,
) vk.DescriptorSetLayoutBinding {
    return .{
        .binding = binding,
        .descriptor_type = descriptor_type,
        .descriptor_count = 1,
        .stage_flags = stageFlags,
        .p_immutable_samplers = null,
    };
}

pub fn descriptorset_layout_create_info(
    bindings: *vk.DescriptorSetLayoutBinding,
    bindingCount: u32,
) vk.DescriptorSetLayoutCreateInfo {
    return .{
        .flags = .{},
        .binding_count = bindingCount,
        .p_bindings = bindings,
    };
}

pub fn write_descriptor_image(
    descriptor_type: vk.DescriptorType,
    dstSet: vk.DescriptorSet,
    imageInfo: *vk.DescriptorImageInfo,
    binding: u32,
) vk.WriteDescriptorSet {
    return .{
        .dst_set = dstSet,
        .dst_binding = binding,
        .dst_array_element = 0,
        .descriptor_count = 1,
        .descriptor_type = descriptor_type,
        .p_image_info = imageInfo,
        .p_buffer_info = .null_handle,
        .p_texel_buffer_view = .null_handle,
    };
}

pub fn write_descriptor_buffer(
    descriptor_type: vk.DescriptorType,
    dstSet: vk.DescriptorSet,
    bufferInfo: *vk.DescriptorBufferInfo,
    binding: u32,
) vk.WriteDescriptorSet {
    return .{
        .dst_set = dstSet,
        .dst_binding = binding,
        .dst_array_element = 0,
        .descriptor_count = 1,
        .descriptor_type = descriptor_type,
        .p_image_info = .null_handle,
        .p_buffer_info = bufferInfo,
        .p_texel_buffer_view = .null_handle,
    };
}

pub fn buffer_info(
    buffer: vk.Buffer,
    offset: vk.DeviceSize,
    range: vk.DeviceSize,
) vk.DescriptorBufferInfo {
    return .{
        .buffer = buffer,
        .offset = offset,
        .range = range,
    };
}

pub fn image_create_info(
    format: vk.Format,
    usageFlags: vk.ImageUsageFlags,
    extent: vk.Extent3D,
) vk.ImageCreateInfo {
    return .{
        // .flags = ImageCreateFlags = .{},
        .image_type = .@"2d",
        .format = format,
        .extent = extent,
        .mip_levels = 1,
        .array_layers = 1,
        // For MSAA. we will not be using it by default, so default it to 1 sample per pixel.
        .samples = .{
            .@"1_bit" = true,
        },
        // Optimal tiling, which means the image is stored on the best gpu format.
        .tiling = .optimal,
        .usage = usageFlags,
        .sharing_mode = .exclusive,
        .queue_family_index_count = 0,
        .p_queue_family_indices = null,
        .initial_layout = .undefined,
    };
}

pub fn imageview_create_info(
    format: vk.Format,
    image: vk.Image,
    aspectFlags: vk.ImageAspectFlags,
) vk.ImageViewCreateInfo {
    return .{
        .flags = .{},
        .image = image,
        .view_type = .@"2d",
        .format = format,
        .components = .{
            .r = .identity,
            .g = .identity,
            .b = .identity,
            .a = .identity,
        },
        .subresource_range = .{
            .aspect_mask = aspectFlags,
            .base_mip_level = 0,
            .level_count = 1,
            .base_array_layer = 0,
            .layer_count = 1,
        },
    };
}

pub fn pipeline_shader_stage_create_info(
    stage: vk.ShaderStageFlagBits,
    shaderModule: vk.ShaderModule,
    entry: ?[*:0]const u8,
) vk.PipelineShaderStageCreateInfo {
    return .{
        .flags = .{},
        .stage = stage,
        .module = shaderModule,
        .p_name = entry orelse &"main",
        .p_specialization_info = null,
    };
}

const std = @import("std");
const vk = @import("vulkan");
