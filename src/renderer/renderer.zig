//! Vulkan Context

pub const Renderer = struct {
    const FRAME_OVERLAP: usize = 2;

    allocator: std.mem.Allocator,
    vk_ctx: *VK_CTX,
    swap_chain: SwapChain,

    extent: vk.Extent2D,

    draw_image: AllocatedImage,

    frames: [FRAME_OVERLAP]FrameData,
    frame_number: usize = 0,

    global_descriptor_allocator: DescriptorAllocator,
    draw_image_descriptors: vk.DescriptorSet,
    draw_image_descriptor_layout: vk.DescriptorSetLayout,

    gradient_pipeline: vk.Pipeline,
    gradient_pipeline_layout: vk.PipelineLayout,

    im_ctx: IM_CTX,
    imgui_ctx: Imgui_CTX,

    pub fn init(
        allocator: std.mem.Allocator,
        window: sdl.video.Window,
        extent: vk.Extent2D,
    ) !Renderer {
        var self: Renderer = undefined;
        self.allocator = allocator;

        self.extent = extent;

        self.vk_ctx = try self.allocator.create(VK_CTX);
        self.vk_ctx.* = try VK_CTX.init(self.allocator, window);
        errdefer self.vk_ctx.deinit();
        std.log.debug("[Engine][Vulkan][Context] Initialized successfully!", .{});

        self.swap_chain = try SwapChain.init(self.vk_ctx, extent);
        errdefer self.swap_chain.deinit();
        std.log.debug("[Engine][Vulkan][Swap Chain] Initialized successfully!", .{});

        self.draw_image = try AllocatedImage.init(self.vk_ctx, extent);
        errdefer self.draw_image.deinit(self.vk_ctx);
        std.log.debug("[Engine][Vulkan][Draw Image] Initialized successfully!", .{});

        try self.init_descriptors();
        std.log.debug("[Engine][Vulkan][Descriptors] Initialized successfully!", .{});

        try self.init_pipelines();
        std.log.debug("[Engine][Vulkan][Pipelines] Initialized successfully!", .{});

        self.im_ctx = try IM_CTX.init(self.vk_ctx);
        errdefer self.im_ctx.deinit(self.vk_ctx);
        std.log.debug("[Engine][Vulkan][Immediate Mode Context] Initialized successfully!", .{});

        self.imgui_ctx = try Imgui_CTX.init(
            self.vk_ctx,
            window,
            self.swap_chain.image_format,
        );
        errdefer self.imgui_ctx.deinit(self.vk_ctx);
        std.log.debug("[Engine][Vulkan][Imgui] Initialized successfully!", .{});

        self.frames = .{
            try FrameData.init(self.vk_ctx),
            try FrameData.init(self.vk_ctx),
        };
        self.frame_number = 0;

        return self;
    }

    pub fn deinit(self: Renderer) void {
        self.vk_ctx.device.deviceWaitIdle() catch @panic("Fuck");

        for (self.frames) |frame| {
            frame.deinit(self.vk_ctx);
        }

        self.imgui_ctx.deinit(self.vk_ctx);
        std.log.debug("[Engine][Vulkan][Imgui] Deinitialized successfully!", .{});
        self.im_ctx.deinit(self.vk_ctx);
        std.log.debug("[Engine][Vulkan][Immediate Mode Context] Deinitialized successfully!", .{});

        self.vk_ctx.device.destroyPipelineLayout(
            self.gradient_pipeline_layout,
            null,
        );
        self.vk_ctx.device.destroyPipeline(
            self.gradient_pipeline,
            null,
        );

        self.global_descriptor_allocator.deinit(self.vk_ctx);
        self.vk_ctx.device.destroyDescriptorSetLayout(
            self.draw_image_descriptor_layout,
            null,
        );

        self.draw_image.deinit(self.vk_ctx);
        std.log.debug("[Engine][Vulkan][Draw Image] Deinitialized successfully!", .{});

        self.swap_chain.deinit();
        std.log.debug("[Engine][Vulkan][Swap Chain] Deinitialized successfully!", .{});

        self.vk_ctx.deinit();
        self.allocator.destroy(self.vk_ctx);
        std.log.debug("[Engine][Vulkan][Context] Deinitialized successfully!", .{});
    }

    // * TODO: Check vk.Result
    pub fn draw(self: *Renderer) !void {
        // Wait until the GPU has finished rendering the last frame.
        // Timeout of 1 second.
        const device = &self.vk_ctx.device;
        const frame: *FrameData = self.get_current_frame();
        _ = try device.waitForFences(
            1,
            @ptrCast(&frame.render_fence),
            vk.TRUE,
            1_000_000_000,
        );
        try device.resetFences(
            1,
            @ptrCast(&frame.render_fence),
        );

        // std.log.debug(">>>>>>>>>>>>>>>> sci :: {d}", .{self.swap_chain.swap_images.len});
        // Request image from swap chain.
        const swap_chain_image_index: u32 = try self.swap_chain.next_image_index(
            frame.swapchain_semaphore,
            .null_handle,
        );
        var image = &self.swap_chain.swap_images[swap_chain_image_index];

        // Commands
        // --------
        const cmd: vk.CommandBuffer = frame.mainCommandBuffer;

        // Now that we are sure that the commands finished executing,
        // we can safely reset the command buffer to begin recording again.
        try device.resetCommandBuffer(cmd, .{});

        // Begin the command buffer recording.
        // We will use this command buffer exactly once,
        // so we want to let vulkan know that.
        const cmd_begin_info: vk.CommandBufferBeginInfo = .{
            .flags = .{
                .one_time_submit_bit = true,
            },
        };

        // Start the command buffer recording.
        try device.beginCommandBuffer(
            cmd,
            &cmd_begin_info,
        );

        // Transition our main draw image into general layout so we can write into it
        // we will overwrite it all so we dont care about what was the older layout
        self.draw_image.transition(
            self.vk_ctx,
            cmd,
            .undefined,
            .general,
        );

        self.draw_background(cmd);

        // Transition the draw image and the swapchain image into their correct transfer layouts.
        self.draw_image.transition(
            self.vk_ctx,
            cmd,
            .general,
            .transfer_src_optimal,
        );
        image.transition(
            self.vk_ctx,
            cmd,
            .undefined,
            .transfer_dst_optimal,
        );

        // Execute a copy from the draw image into the swap chain.
        image.copy_into(
            self.vk_ctx,
            cmd,
            self.draw_image.handle,
            self.extent,
            self.swap_chain.extent,
        );

        image.transition(
            self.vk_ctx,
            cmd,
            .transfer_dst_optimal,
            .color_attachment_optimal,
        );

        self.imgui_ctx.vulkan_draw(
            self.vk_ctx,
            cmd,
            image.view,
            self.extent,
        );

        image.transition(
            self.vk_ctx,
            cmd,
            .color_attachment_optimal,
            .present_src_khr,
        );

        // Finalize the command buffer.
        // We can no longer add commands, but it can now be executed.
        try device.endCommandBuffer(cmd);

        // Prepare the submission to the queue.
        // --------------------------------------------------------------------
        // We want to wait on the _presentSemaphore,
        // as that semaphore is signaled when the swap chain is ready.
        //
        // We will signal the `image.render_finished`,
        // to signal that rendering has finished.
        const cmd_info: vk.CommandBufferSubmitInfo = .{
            .command_buffer = cmd,
            .device_mask = 0,
        };

        var wait_info: vk.SemaphoreSubmitInfo = vk_init.semaphore_submit_info(
            .{
                .color_attachment_output_bit = true,
            },
            frame.swapchain_semaphore,
        );
        var signal_info: vk.SemaphoreSubmitInfo = vk_init.semaphore_submit_info(
            .{
                .all_graphics_bit = true,
            },
            image.render_finished,
        );

        const submit: vk.SubmitInfo2 = vk_init.submit_info(
            &cmd_info,
            &signal_info,
            &wait_info,
        );

        // Submit command buffer to the queue and execute it.
        // `frame.render_fence` will now block until
        // the graphic commandsfinish execution
        try device.queueSubmit2(
            self.vk_ctx.graphics_queue.handle,
            1,
            @ptrCast(&submit),
            frame.render_fence,
        );

        // Prepare present.
        // --------------------------------------------------------------------
        // This will put the image we just rendered to into the visible window.
        // we want to wait on the `image.render_finished` for that,
        // as its necessary that drawing commands have finished
        // before the image is displayed to the user
        const present_info: vk.PresentInfoKHR = .{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast(&image.render_finished),
            .swapchain_count = 1,
            .p_swapchains = @ptrCast(&self.swap_chain.handle),
            .p_image_indices = @ptrCast(&swap_chain_image_index),
            .p_results = null,
        };

        _ = try device.queuePresentKHR(
            self.vk_ctx.graphics_queue.handle,
            &present_info,
        );

        // Increase the number of frames drawn.
        self.frame_number += 1;
    }

    fn draw_background(self: *Renderer, cmd: vk.CommandBuffer) void {
        // self.draw_background_flashing(cmd);
        self.draw_background_gradient(cmd);
    }

    fn draw_background_flashing(self: *Renderer, cmd: vk.CommandBuffer) void {
        // Make a clear-color from frame number.
        // This will flash with a 120 frame period.
        const flash: f32 = @abs(@sin(
            @as(f32, @floatFromInt(self.frame_number)) / 120.0,
        ));
        const clear_value: vk.ClearColorValue = .{
            .float_32 = .{
                0.0,
                0.0,
                flash,
                1.0,
            },
        };

        const clear_range: vk.ImageSubresourceRange = vk_init.image_subresource_range(
            .{ .color_bit = true },
        );

        // Clear image.
        self.vk_ctx.device.cmdClearColorImage(
            cmd,
            self.draw_image.handle,
            .general,
            &clear_value,
            1,
            @ptrCast(&clear_range),
        );
    }

    fn draw_background_gradient(self: *Renderer, cmd: vk.CommandBuffer) void {
        // Bind the gradient drawing compute pipeline.
        self.vk_ctx.device.cmdBindPipeline(
            cmd,
            .compute,
            self.gradient_pipeline,
        );

        // Bind the descriptor set containing the draw image for the compute pipeline.
        self.vk_ctx.device.cmdBindDescriptorSets(
            cmd,
            .compute,
            self.gradient_pipeline_layout,
            0,
            1,
            @ptrCast(&self.draw_image_descriptors),
            0,
            null,
        );

        // Execute the compute pipeline dispatch. We are using 16x16 workgroup size so we need to divide by it.
        self.vk_ctx.device.cmdDispatch(
            cmd,
            @intFromFloat(@ceil(@as(f32, @floatFromInt(self.extent.width)) / 16.0)),
            @intFromFloat(@ceil(@as(f32, @floatFromInt(self.extent.height)) / 16.0)),
            1,
        );
        // vkCmdDispatch(cmd, std::ceil(_drawExtent.width / 16.0), std::ceil(_drawExtent.height / 16.0), 1);
    }

    fn get_current_frame(self: *Renderer) *FrameData {
        return &self.frames[self.frame_number % FRAME_OVERLAP];
    }

    fn init_descriptors(self: *Renderer) !void {
        // Create a descriptor pool that will hold 10 sets with 1 image each.
        const sizes: [1]DescriptorAllocator.PoolSizeRatio = .{
            .{
                .descriptor_type = .storage_image,
                .ratio = 1.0,
            },
        };

        self.global_descriptor_allocator = try DescriptorAllocator.init(
            self.vk_ctx,
            10,
            sizes[0..],
        );

        // Make the descriptor set layout for our compute draw.
        {
            var builder: DescriptorLayoutBuilder = DescriptorLayoutBuilder.init(self.allocator);
            defer builder.deinit();

            try builder.add_binding(0, .storage_image);

            self.draw_image_descriptor_layout = try builder.build(
                self.vk_ctx,
                .{ .compute_bit = true },
                null,
                .{},
            );
        }

        // Allocate a descriptor set for our draw image.
        self.draw_image_descriptors = try self.global_descriptor_allocator.allocate(
            self.vk_ctx,
            self.draw_image_descriptor_layout,
        );

        const img_info: vk.DescriptorImageInfo = .{
            .sampler = .null_handle,
            .image_view = self.draw_image.view,
            .image_layout = .general,
        };

        const draw_image_write: vk.WriteDescriptorSet = .{
            .dst_set = self.draw_image_descriptors,
            .dst_binding = 0,
            .dst_array_element = 0, // Default value.
            .descriptor_count = 1,
            .descriptor_type = .storage_image,
            .p_image_info = @ptrCast(&img_info),
            .p_buffer_info = @ptrCast(@alignCast(&.null_handle)),
            .p_texel_buffer_view = @ptrCast(@alignCast(&.null_handle)),
        };

        self.vk_ctx.device.updateDescriptorSets(
            1,
            @ptrCast(&draw_image_write),
            0,
            null,
        );
    }

    fn init_pipelines(self: *Renderer) !void {
        try self.init_background_pipeline();
    }

    fn init_background_pipeline(self: *Renderer) !void {
        const compute_layout: vk.PipelineLayoutCreateInfo = .{
            .set_layout_count = 1,
            .p_set_layouts = @ptrCast(&self.draw_image_descriptor_layout),
        };

        self.gradient_pipeline_layout = try self.vk_ctx.device.createPipelineLayout(
            &compute_layout,
            null,
        );

        const compute_draw_shader: vk.ShaderModule = try shaders.load_module(
            self.vk_ctx,
            "./shaders/gradient.comp.spv",
        );

        const stage_info: vk.PipelineShaderStageCreateInfo = .{
            .stage = .{
                .compute_bit = true,
            },
            .module = compute_draw_shader,
            .p_name = "main",
        };

        const compute_pipeline_create_info: vk.ComputePipelineCreateInfo = .{
            .layout = self.gradient_pipeline_layout,
            .stage = stage_info,
            .base_pipeline_index = 0,
        };

        if (try self.vk_ctx.device.createComputePipelines(
            .null_handle,
            1,
            @ptrCast(&compute_pipeline_create_info),
            null,
            @ptrCast(&self.gradient_pipeline),
        ) != .success) {
            return error.FailedToCreateComputePipeline;
        }

        self.vk_ctx.device.destroyShaderModule(
            compute_draw_shader,
            null,
        );
    }

    // fn immediate_submit(self: *Renderer, function: *const fn (cmd: vk.CommandBuffer) void) void {}
    // fn init_imgui(self: *Renderer) void {}
};

const std = @import("std");

const sdl = @import("sdl3");
const vk = @import("vulkan");

const AllocatedImage = @import("./allocated_image.zig").AllocatedImage;
const DescriptorAllocator = @import("./descriptors.zig").DescriptorAllocator;
const DescriptorLayoutBuilder = @import("./descriptors.zig").DescriptorLayoutBuilder;
const FrameData = @import("./frame_data.zig").FrameData;
const SwapChain = @import("./swap_chain.zig").SwapChain;
const VK_CTX = @import("./vk_ctx.zig").VK_CTX;
const IM_CTX = @import("./vk_ctx_im.zig").IM_CTX;
const Imgui_CTX = @import("./imgui_ctx.zig").Imgui_CTX;
const vk_init = @import("./vk_initializers.zig");
const shaders = @import("./shaders.zig");
