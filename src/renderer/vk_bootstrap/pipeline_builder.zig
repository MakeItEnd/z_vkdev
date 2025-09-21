pub const PieplineBuilder = struct {
    vk_ctx: *VK_CTX,

    shader_stages: std.array_list.Aligned(vk.PipelineShaderStageCreateInfo, null),

    input_assembly: vk.PipelineInputAssemblyStateCreateInfo,
    rasterizer: vk.PipelineRasterizationStateCreateInfo,
    color_blend_attachment: vk.PipelineColorBlendAttachmentState,
    multisampling: vk.PipelineMultisampleStateCreateInfo,
    pipeline_layout: vk.PipelineLayout,
    depth_stencil: vk.PipelineDepthStencilStateCreateInfo,
    render_info: vk.PipelineRenderingCreateInfo,
    color_attachment_format: vk.Format,

    pub fn init(
        vk_ctx: *VK_CTX,
    ) !PieplineBuilder {
        var self: PieplineBuilder = undefined;
        self.vk_ctx = vk_ctx;
        self.shader_stages = try .initCapacity(vk_ctx.allocator, 2);

        self.clear();

        return self;
    }

    pub fn deinit(self: *PieplineBuilder) void {
        self.clear();

        self.shader_stages.deinit(self.vk_ctx.allocator);
    }

    pub fn clear(self: *PieplineBuilder) void {
        self.input_assembly = .{
            .topology = .point_list,
            .primitive_restart_enable = 0,
        };
        self.rasterizer = std.mem.zeroes(vk.PipelineRasterizationStateCreateInfo);
        self.rasterizer.s_type = .pipeline_rasterization_state_create_info;
        self.color_blend_attachment = std.mem.zeroes(vk.PipelineColorBlendAttachmentState);
        self.multisampling = std.mem.zeroes(vk.PipelineMultisampleStateCreateInfo);
        self.multisampling.s_type = .pipeline_multisample_state_create_info;
        self.pipeline_layout = .null_handle;
        self.depth_stencil = std.mem.zeroes(vk.PipelineDepthStencilStateCreateInfo);
        self.depth_stencil.s_type = .pipeline_depth_stencil_state_create_info;
        self.render_info = std.mem.zeroes(vk.PipelineRenderingCreateInfo);
        self.render_info.s_type = .pipeline_rendering_create_info;

        self.shader_stages.clearRetainingCapacity();
    }

    pub fn build(self: *PieplineBuilder) vk.Pipeline {
        // Make viewport state from our stored viewport and scissor.
        // At the moment we wont support multiple viewports or scissors.
        const viewport_state: vk.PipelineViewportStateCreateInfo = .{
            .viewport_count = 1,
            .scissor_count = 1,
        };

        // Setup dummy color blending. We arent using transparent objects yet
        // the blending is just "no blend", but we do write to the color attachment.
        const color_blending: vk.PipelineColorBlendStateCreateInfo = .{
            .logic_op_enable = vk.FALSE,
            .logic_op = vk.LogicOp.copy,
            .attachment_count = 1,
            .p_attachments = @ptrCast(&self.color_blend_attachment),
            .blend_constants = .{ 0.0, 0.0, 0.0, 0.0 },
        };

        // Completely clear VertexInputStateCreateInfo, as we have no need for it.
        const vertex_input_info: vk.PipelineVertexInputStateCreateInfo = .{};

        // Setup up dynamic state.
        const state: [2]vk.DynamicState = .{ vk.DynamicState.viewport, vk.DynamicState.scissor };
        const dynamic_info: vk.PipelineDynamicStateCreateInfo = .{
            .p_dynamic_states = @ptrCast(&state),
            .dynamic_state_count = 2,
        };

        // Build the actual pipeline.
        // We now use all of the info structs we have been writing into into this one
        // to create the pipeline.
        const pipeline_info: vk.GraphicsPipelineCreateInfo = .{
            // Connect the render_info to the pNext extension mechanism.
            .p_next = &self.render_info,

            .stage_count = @intCast(self.shader_stages.items.len),
            .p_stages = @ptrCast(self.shader_stages.items.ptr),
            .p_vertex_input_state = &vertex_input_info,
            .p_input_assembly_state = &self.input_assembly,
            .p_viewport_state = &viewport_state,
            .p_rasterization_state = &self.rasterizer,
            .p_multisample_state = &self.multisampling,
            .p_color_blend_state = &color_blending,
            .p_depth_stencil_state = &self.depth_stencil,
            .layout = self.pipeline_layout,
            .p_dynamic_state = &dynamic_info,

            .subpass = 0,
            .base_pipeline_index = 0,
        };

        // its easy to error out on create graphics pipeline, so we handle it a bit
        // better than the common VK_CHECK case
        var new_pipeline: vk.Pipeline = vk.Pipeline.null_handle;
        _ = self.vk_ctx.device.createGraphicsPipelines(
            vk.PipelineCache.null_handle,
            1,
            @ptrCast(&pipeline_info),
            null,
            @ptrCast(&new_pipeline),
        ) catch |err| {
            std.log.err("Failed to create pipeline: {any}.", .{err});

            return vk.Pipeline.null_handle;
        };

        return new_pipeline;
    }

    pub fn set_shaders(
        self: *PieplineBuilder,
        vertex_shader: vk.ShaderModule,
        fragment_shader: vk.ShaderModule,
    ) void {
        self.shader_stages.clearRetainingCapacity();

        self.shader_stages.appendAssumeCapacity(vk_init.pipeline_shader_stage_create_info(
            .{ .vertex_bit = true },
            vertex_shader,
            null,
        ));
        self.shader_stages.appendAssumeCapacity(vk_init.pipeline_shader_stage_create_info(
            .{ .fragment_bit = true },
            fragment_shader,
            null,
        ));
    }

    pub fn set_input_topology(
        self: *PieplineBuilder,
        topology: vk.PrimitiveTopology,
    ) void {
        self.input_assembly.topology = topology;
        // We are not going to use primitive restart on the entire tutorial so leave it on false.
        self.input_assembly.primitive_restart_enable = vk.FALSE;
    }

    pub fn set_polygon_mode(
        self: *PieplineBuilder,
        mode: vk.PolygonMode,
    ) void {
        self.rasterizer.polygon_mode = mode;
        self.rasterizer.line_width = 1.0;
    }

    pub fn set_cull_mode(
        self: *PieplineBuilder,
        cull_mode: vk.CullModeFlags,
        front_face: vk.FrontFace,
    ) void {
        self.rasterizer.cull_mode = cull_mode;
        self.rasterizer.front_face = front_face;
    }

    pub fn set_multisampling_none(
        self: *PieplineBuilder,
    ) void {
        self.multisampling.sample_shading_enable = vk.FALSE;
        // Multisampling defaulted to no multisampling. (1 sample per pixel)
        self.multisampling.rasterization_samples = .{ .@"1_bit" = true };
        self.multisampling.min_sample_shading = 1.0;
        self.multisampling.p_sample_mask = null;
        // No alpha to coverage either.
        self.multisampling.alpha_to_coverage_enable = vk.FALSE;
        self.multisampling.alpha_to_one_enable = vk.FALSE;
    }

    pub fn disable_blending(
        self: *PieplineBuilder,
    ) void {
        // Default write mask.
        self.color_blend_attachment.color_write_mask = .{
            .r_bit = true,
            .g_bit = true,
            .b_bit = true,
            .a_bit = true,
        };
        // No blending.
        self.color_blend_attachment.blend_enable = vk.FALSE;
    }

    pub fn set_color_attachment_format(
        self: *PieplineBuilder,
        format: vk.Format,
    ) void {
        self.color_attachment_format = format;
        // Connect the format to the render_info structure.
        self.render_info.color_attachment_count = 1;
        self.render_info.p_color_attachment_formats = @ptrCast(&self.color_attachment_format);
    }

    pub fn set_depth_format(
        self: *PieplineBuilder,
        format: vk.Format,
    ) void {
        self.render_info.depth_attachment_format = format;
    }

    pub fn disable_depthtest(
        self: *PieplineBuilder,
    ) void {
        self.depth_stencil.depth_test_enable = vk.FALSE;
        self.depth_stencil.depth_write_enable = vk.FALSE;
        self.depth_stencil.depth_compare_op = .never;
        self.depth_stencil.depth_bounds_test_enable = vk.FALSE;
        self.depth_stencil.stencil_test_enable = vk.FALSE;
        self.depth_stencil.front = std.mem.zeroes(vk.StencilOpState);
        self.depth_stencil.back = std.mem.zeroes(vk.StencilOpState);
        self.depth_stencil.min_depth_bounds = 0.0;
        self.depth_stencil.max_depth_bounds = 1.0;
    }
};

const std = @import("std");
const sdl3 = @import("sdl3");
const vk = @import("vulkan");

const VK_CTX = @import("../vk_ctx.zig").VK_CTX;
const vk_init = @import("../vk_initializers.zig");
