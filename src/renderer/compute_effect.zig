pub const ComputeEffect = struct {
    name: []const u8,

    layout: vk.PipelineLayout,
    pipeline: vk.Pipeline,

    data: ComputePushConstants,

    pub fn create(
        vk_ctx: *const VK_CTX,
        shader_path: []const u8,
        name: []const u8,
        data: ComputePushConstants,
        draw_image_descriptor_layout: *const vk.DescriptorSetLayout,
    ) !ComputeEffect {
        var self: ComputeEffect = .{
            .name = name,
            .layout = vk.PipelineLayout.null_handle,
            .pipeline = vk.Pipeline.null_handle,
            .data = data,
        };

        const push_constant: vk.PushConstantRange = .{
            .stage_flags = .{ .compute_bit = true },
            .offset = 0,
            .size = @sizeOf(ComputePushConstants),
        };

        const compute_layout: vk.PipelineLayoutCreateInfo = .{
            .set_layout_count = 1,
            .p_set_layouts = @ptrCast(draw_image_descriptor_layout),
            .push_constant_range_count = 1,
            .p_push_constant_ranges = @ptrCast(&push_constant),
        };

        self.layout = try vk_ctx.device.createPipelineLayout(
            &compute_layout,
            null,
        );

        const compute_draw_shader: vk.ShaderModule = try shaders.load_module(
            vk_ctx,
            shader_path,
        );

        const stage_info: vk.PipelineShaderStageCreateInfo = .{
            .stage = .{
                .compute_bit = true,
            },
            .module = compute_draw_shader,
            .p_name = "main",
        };

        const compute_pipeline_create_info: vk.ComputePipelineCreateInfo = .{
            .layout = self.layout,
            .stage = stage_info,
            .base_pipeline_index = 0,
        };

        if (try vk_ctx.device.createComputePipelines(
            .null_handle,
            1,
            @ptrCast(&compute_pipeline_create_info),
            null,
            @ptrCast(&self.pipeline),
        ) != .success) {
            return error.FailedToCreateComputePipeline;
        }

        vk_ctx.device.destroyShaderModule(
            compute_draw_shader,
            null,
        );

        return self;
    }

    pub fn deinit(self: ComputeEffect, vk_ctx: *const VK_CTX) void {
        vk_ctx.device.destroyPipelineLayout(
            self.layout,
            null,
        );

        vk_ctx.device.destroyPipeline(
            self.pipeline,
            null,
        );
    }
};

const std = @import("std");
const vk = @import("vulkan");

const VK_CTX = @import("./vk_ctx.zig").VK_CTX;
const ComputePushConstants = @import("./push_constants.zig").ComputePushConstants;
const shaders = @import("./shaders.zig");
