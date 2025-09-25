//! Vulkan Context

pub const Renderer = struct {
    const FRAME_OVERLAP: usize = 2;

    allocator: std.mem.Allocator,
    vk_ctx: *VK_CTX,
    im_ctx: IM_CTX,
    swap_chain: SwapChain,

    extent: vk.Extent2D,

    draw_image: AllocatedImage,

    frames: [FRAME_OVERLAP]FrameData,
    frame_number: usize = 0,

    global_descriptor_allocator: DescriptorAllocator,
    draw_image_descriptors: vk.DescriptorSet,
    draw_image_descriptor_layout: vk.DescriptorSetLayout,

    compute_effects: std.array_list.Aligned(ComputeEffect, null),
    compute_effects_index: usize,

    triangle_pipeline_layout: vk.PipelineLayout,
    triangle_pipeline: vk.Pipeline,

    mesh_pipeline_layout: vk.PipelineLayout,
    mesh_pipeline: vk.Pipeline,
    rectangle: GPUMeshBuffers,

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

        self.im_ctx = try IM_CTX.init(self.vk_ctx);
        errdefer self.im_ctx.deinit(self.vk_ctx);
        std.log.debug("[Engine][Vulkan][Immediate Mode Context] Initialized successfully!", .{});

        self.swap_chain = try SwapChain.init(self.vk_ctx, extent);
        errdefer self.swap_chain.deinit();
        std.log.debug("[Engine][Vulkan][Swap Chain] Initialized successfully!", .{});

        self.draw_image = try AllocatedImage.init(self.vk_ctx, extent);
        errdefer self.draw_image.deinit(self.vk_ctx);
        std.log.debug("[Engine][Vulkan][Draw Image] Initialized successfully!", .{});

        try self.init_descriptors();
        std.log.debug("[Engine][Vulkan][Descriptors] Initialized successfully!", .{});

        self.compute_effects = .{};
        self.compute_effects_index = 0;
        try self.init_pipelines();
        std.log.debug("[Engine][Vulkan][Pipelines] Initialized successfully!", .{});

        self.frames = .{
            try FrameData.init(self.vk_ctx),
            try FrameData.init(self.vk_ctx),
        };
        self.frame_number = 0;

        try self.init_default_data();

        return self;
    }

    pub fn deinit(self: *Renderer) void {
        self.vk_ctx.device.deviceWaitIdle() catch @panic("Fuck");

        for (self.frames) |frame| {
            frame.deinit(self.vk_ctx);
        }

        self.rectangle.deinit(self.vk_ctx);

        self.vk_ctx.device.destroyPipelineLayout(self.triangle_pipeline_layout, null);
        self.vk_ctx.device.destroyPipeline(self.triangle_pipeline, null);
        self.vk_ctx.device.destroyPipelineLayout(self.mesh_pipeline_layout, null);
        self.vk_ctx.device.destroyPipeline(self.mesh_pipeline, null);

        for (self.compute_effects.items) |compute_effect| {
            compute_effect.deinit(self.vk_ctx);
        }
        self.compute_effects.deinit(self.allocator);

        self.global_descriptor_allocator.deinit(self.vk_ctx);
        self.vk_ctx.device.destroyDescriptorSetLayout(
            self.draw_image_descriptor_layout,
            null,
        );

        self.draw_image.deinit(self.vk_ctx);
        std.log.debug("[Engine][Vulkan][Draw Image] Deinitialized successfully!", .{});

        self.swap_chain.deinit();
        std.log.debug("[Engine][Vulkan][Swap Chain] Deinitialized successfully!", .{});

        self.im_ctx.deinit(self.vk_ctx);
        std.log.debug("[Engine][Vulkan][Immediate Mode Context] Deinitialized successfully!", .{});

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

        self.draw_image.transition(
            self.vk_ctx,
            cmd,
            .general,
            .color_attachment_optimal,
        );

        self.draw_geometry(cmd);

        // Transition the draw image and the swapchain image into their correct transfer layouts.
        self.draw_image.transition(
            self.vk_ctx,
            cmd,
            .color_attachment_optimal,
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

    pub fn upload_mesh(
        self: *Renderer,
        indicies: []const u32,
        vertices: []const Vertex,
    ) !GPUMeshBuffers {
        const vertex_buffer_size: usize = vertices.len * @sizeOf(Vertex);
        const index_buffer_size: usize = indicies.len * @sizeOf(u32);

        var new_surface: GPUMeshBuffers = undefined;

        // Create vertex buffer.
        new_surface.vertex_buffer = try AllocatedBuffer.init(
            self.vk_ctx,
            vertex_buffer_size,
            .{
                .storage_buffer_bit = true,
                .transfer_dst_bit = true,
                .shader_device_address_bit = true,
            },
            .gpu_only,
        );

        // Find the address of the vertex buffer.
        new_surface.vertex_buffer_address = self.vk_ctx.device.getBufferDeviceAddress(&.{
            .buffer = new_surface.vertex_buffer.handle,
        });

        // Create index buffer.
        new_surface.index_buffer = try AllocatedBuffer.init(
            self.vk_ctx,
            index_buffer_size,
            .{
                .index_buffer_bit = true,
                .transfer_dst_bit = true,
            },
            .gpu_only,
        );

        // Use a staging buffer to write data to the buffers.
        const staging: AllocatedBuffer = try AllocatedBuffer.init(
            self.vk_ctx,
            vertex_buffer_size + index_buffer_size,
            .{
                .transfer_src_bit = true,
            },
            .cpu_only,
        );
        defer staging.deinit(self.vk_ctx);

        // void* mappedData;
        // vmaMapMemory(allocator->handle, _allocation, &mappedData);
        // memcpy(mappedData, data.data(), bufferSize);
        var data: ?*anyopaque = undefined;
        try self.vk_ctx.vma.memoryMap(staging.allocation, @ptrCast(&data));
        defer self.vk_ctx.vma.memoryUnmap(staging.allocation);
        const aligned_data: [*]Vertex = @ptrCast(@alignCast(data));
        // Copy vertex buffer.
        @memcpy(aligned_data, vertices);
        // c.vma.UnmapMemory(self.vma_allocator, staging_buffer.allocation);
        // Copy index buffer.
        const aligned_data2: [*]u32 = @ptrCast(@alignCast(@as([*]u8, @ptrCast(@alignCast(data))) + vertex_buffer_size));
        @memcpy(aligned_data2, indicies);
        // memcpy(data, vertices.data(), vertexBufferSize);
        // memcpy((char*)data + vertexBufferSize, indices.data(), indexBufferSize);

        { // Immediate submit.
            const cmd = try self.im_ctx.submit_begin(self.vk_ctx);

            const vertex_copy: vk.BufferCopy = .{
                .src_offset = 0,
                .dst_offset = 0,
                .size = vertex_buffer_size,
            };
            self.vk_ctx.device.cmdCopyBuffer(
                cmd,
                staging.handle,
                new_surface.vertex_buffer.handle,
                1,
                @ptrCast(&vertex_copy),
            );

            const index_copy: vk.BufferCopy = .{
                .src_offset = vertex_buffer_size,
                .dst_offset = 0,
                .size = index_buffer_size,
            };
            self.vk_ctx.device.cmdCopyBuffer(
                cmd,
                staging.handle,
                new_surface.index_buffer.handle,
                1,
                @ptrCast(&index_copy),
            );

            try self.im_ctx.submit_end(self.vk_ctx, cmd);
        }

        return new_surface;
    }

    fn init_default_data(self: *Renderer) !void {
        const rect_vertices: [4]Vertex = .{
            .{
                .position = .{ 0.5, -0.5, 0.0 },
                .uv_x = 0.0,
                .normal = .{ 0.0, 0.0, 0.0 },
                .uv_y = 0.0,
                .color = .{ 0.0, 0.0, 0.0, 1.0 },
            },
            .{
                .position = .{ 0.5, 0.5, 0.0 },
                .uv_x = 0.0,
                .normal = .{ 0.0, 0.0, 0.0 },
                .uv_y = 0.0,
                .color = .{ 0.5, 0.5, 0.5, 1.0 },
            },
            .{
                .position = .{ -0.5, -0.5, 0.0 },
                .uv_x = 0.0,
                .normal = .{ 0.0, 0.0, 0.0 },
                .uv_y = 0.0,
                .color = .{ 1.0, 0.0, 0.0, 1.0 },
            },
            .{
                .position = .{ -0.5, 0.5, 0.0 },
                .uv_x = 0.0,
                .normal = .{ 0.0, 0.0, 0.0 },
                .uv_y = 0.0,
                .color = .{ 0.0, 1.0, 0.0, 1.0 },
            },
        };

        const rect_indices: [6]u32 = .{ 0, 1, 2, 2, 1, 3 };

        self.rectangle = try self.upload_mesh(&rect_indices, &rect_vertices);
    }

    fn draw_background(self: *Renderer, cmd: vk.CommandBuffer) void {
        // self.draw_background_flashing(cmd);
        // self.draw_background_gradient(cmd);
        // self.draw_background_gradient_with_push_constants(cmd);
        self.draw_compute_effect(cmd);
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

    fn draw_background_gradient_with_push_constants(self: *Renderer, cmd: vk.CommandBuffer) void {
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

        const pc: ComputePushConstants = .{
            .data1 = .{ 1, 0, 0, 1 },
            .data2 = .{ 0, 0, 1, 1 },
            .data3 = .{ 0, 0, 0, 0 },
            .data4 = .{ 0, 0, 0, 0 },
        };
        self.vk_ctx.device.cmdPushConstants(
            cmd,
            self.gradient_pipeline_layout,
            .{
                .compute_bit = true,
            },
            0,
            @sizeOf(ComputePushConstants),
            @ptrCast(&pc),
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

    fn draw_compute_effect(self: *Renderer, cmd: vk.CommandBuffer) void {
        // Bind the gradient drawing compute pipeline.
        self.vk_ctx.device.cmdBindPipeline(
            cmd,
            .compute,
            self.compute_effects.items[self.compute_effects_index].pipeline,
        );

        // Bind the descriptor set containing the draw image for the compute pipeline.
        self.vk_ctx.device.cmdBindDescriptorSets(
            cmd,
            .compute,
            self.compute_effects.items[self.compute_effects_index].layout,
            0,
            1,
            @ptrCast(&self.draw_image_descriptors),
            0,
            null,
        );

        self.vk_ctx.device.cmdPushConstants(
            cmd,
            self.compute_effects.items[self.compute_effects_index].layout,
            .{
                .compute_bit = true,
            },
            0,
            @sizeOf(ComputePushConstants),
            @ptrCast(&self.compute_effects.items[self.compute_effects_index].data),
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
        try self.compute_effects.append(self.allocator, try ComputeEffect.create(
            self.vk_ctx,
            "./shaders/gradient.comp.spv",
            "gradient",
            .zero,
            &self.draw_image_descriptor_layout,
        ));

        try self.compute_effects.append(self.allocator, try ComputeEffect.create(
            self.vk_ctx,
            "./shaders/gradient_color.comp.spv",
            "gradient_color",
            .{
                .data1 = .{ 1, 0, 0, 1 },
                .data2 = .{ 0, 0, 1, 1 },
                .data3 = .{ 0, 0, 0, 0 },
                .data4 = .{ 0, 0, 0, 0 },
            },
            &self.draw_image_descriptor_layout,
        ));

        try self.compute_effects.append(self.allocator, try ComputeEffect.create(
            self.vk_ctx,
            "./shaders/sky.comp.spv",
            "sky",
            .{
                .data1 = .{ 0.1, 0.2, 0.4, 1.97 },
                .data2 = .{ 0, 0, 0, 0 },
                .data3 = .{ 0, 0, 0, 0 },
                .data4 = .{ 0, 0, 0, 0 },
            },
            &self.draw_image_descriptor_layout,
        ));

        try self.init_triangle_pipeline();
        try self.init_mesh_pipeline();
    }

    fn init_triangle_pipeline(self: *Renderer) !void {
        const triangle_fragment_shader: vk.ShaderModule = try shaders.load_module(
            self.vk_ctx,
            "./shaders/colored_triangle.frag.spv",
        );
        std.log.debug("[Renderer][Pipeline]<Triangle> Fragment shader succesfully loaded.", .{});

        const triangle_vertex_shader: vk.ShaderModule = try shaders.load_module(
            self.vk_ctx,
            "./shaders/colored_triangle.vert.spv",
        );
        std.log.debug("[Renderer][Pipeline]<Triangle> Vertex shader succesfully loaded.", .{});

        // Build the pipeline layout that controls the inputs/outputs of the shader.
        // We are not using descriptor sets or other systems yet,
        // so no need to use anything other thantriangle_fragment_shader empty default.
        const pipeline_layout_info: vk.PipelineLayoutCreateInfo = .{};
        self.triangle_pipeline_layout = try self.vk_ctx.device.createPipelineLayout(
            &pipeline_layout_info,
            null,
        );

        var pipeline_builder: vkb.PieplineBuilder = try vkb.PieplineBuilder.init(self.vk_ctx);
        defer pipeline_builder.deinit();

        // Use the triangle layout we created.
        pipeline_builder.pipeline_layout = self.triangle_pipeline_layout;
        // Connecting the vertex and pixel shaders to the pipeline.
        pipeline_builder.set_shaders(triangle_vertex_shader, triangle_fragment_shader);
        // It will draw triangles.
        pipeline_builder.set_input_topology(.triangle_list);
        // Filled triangles.
        pipeline_builder.set_polygon_mode(.fill);
        // No backface culling.
        pipeline_builder.set_cull_mode(.{}, .clockwise);
        // No multisampling.draw_geometry()
        pipeline_builder.set_multisampling_none();
        // No blending.
        pipeline_builder.disable_blending();
        // No depth testing.
        pipeline_builder.disable_depthtest();

        // Connect the image format we will draw into, from draw image.
        pipeline_builder.set_color_attachment_format(self.draw_image.format);
        pipeline_builder.set_depth_format(.undefined);

        // Finally build the pipeline.
        self.triangle_pipeline = pipeline_builder.build();

        // Clean structures.
        self.vk_ctx.device.destroyShaderModule(triangle_fragment_shader, null);
        self.vk_ctx.device.destroyShaderModule(triangle_vertex_shader, null);
    }

    fn init_mesh_pipeline(self: *Renderer) !void {
        const triangle_fragment_shader: vk.ShaderModule = try shaders.load_module(
            self.vk_ctx,
            "./shaders/colored_triangle.frag.spv",
        );
        std.log.debug("[Renderer][Pipeline]<Rectangle> Fragment shader succesfully loaded.", .{});

        const triangle_vertex_shader: vk.ShaderModule = try shaders.load_module(
            self.vk_ctx,
            "./shaders/colored_triangle_mesh.vert.spv",
        );
        std.log.debug("[Renderer][Pipeline]<Rectangle> Vertex shader succesfully loaded.", .{});

        const buffer_range: vk.PushConstantRange = .{
            .stage_flags = .{ .vertex_bit = true },
            .offset = 0,
            .size = @sizeOf(GPUDrawPushConstants),
        };

        // Build the pipeline layout that controls the inputs/outputs of the shader.
        // We are not using descriptor sets or other systems yet,
        // so no need to use anything other thantriangle_fragment_shader empty default.
        const pipeline_layout_info: vk.PipelineLayoutCreateInfo = .{
            .push_constant_range_count = 1,
            .p_push_constant_ranges = @ptrCast(&buffer_range),
        };
        self.mesh_pipeline_layout = try self.vk_ctx.device.createPipelineLayout(
            &pipeline_layout_info,
            null,
        );

        var pipeline_builder: vkb.PieplineBuilder = try vkb.PieplineBuilder.init(self.vk_ctx);
        defer pipeline_builder.deinit();

        // Use the triangle layout we created.
        pipeline_builder.pipeline_layout = self.mesh_pipeline_layout;
        // Connecting the vertex and pixel shaders to the pipeline.
        pipeline_builder.set_shaders(triangle_vertex_shader, triangle_fragment_shader);
        // It will draw triangles.
        pipeline_builder.set_input_topology(.triangle_list);
        // Filled triangles.
        pipeline_builder.set_polygon_mode(.fill);
        // No backface culling.
        pipeline_builder.set_cull_mode(.{}, .clockwise);
        // No multisampling.draw_geometry()
        pipeline_builder.set_multisampling_none();
        // No blending.
        pipeline_builder.disable_blending();
        // No depth testing.
        pipeline_builder.disable_depthtest();

        // Connect the image format we will draw into, from draw image.
        pipeline_builder.set_color_attachment_format(self.draw_image.format);
        pipeline_builder.set_depth_format(.undefined);

        // Finally build the pipeline.
        self.mesh_pipeline = pipeline_builder.build();

        // Clean structures.
        self.vk_ctx.device.destroyShaderModule(triangle_fragment_shader, null);
        self.vk_ctx.device.destroyShaderModule(triangle_vertex_shader, null);
    }

    fn draw_geometry(self: *Renderer, cmd: vk.CommandBuffer) void {
        // Begin a render pass connected to our draw image.
        var color_attachment: vk.RenderingAttachmentInfo = vk_init.attachment_info(
            self.draw_image.view,
            null,
            .color_attachment_optimal,
        );

        const render_info: vk.RenderingInfo = vk_init.rendering_info(
            self.extent,
            &color_attachment,
            null,
        );
        self.vk_ctx.device.cmdBeginRendering(
            cmd,
            @ptrCast(&render_info),
        );

        self.vk_ctx.device.cmdBindPipeline(
            cmd,
            .graphics,
            self.triangle_pipeline,
        );

        // Set dynamic viewport and scissor.
        const viewport: vk.Viewport = .{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(self.extent.width),
            .height = @floatFromInt(self.extent.height),
            .min_depth = 0.0,
            .max_depth = 1.0,
        };

        self.vk_ctx.device.cmdSetViewport(
            cmd,
            0,
            1,
            @ptrCast(&viewport),
        );

        const scissor: vk.Rect2D = .{
            .offset = .{
                .x = 0,
                .y = 0,
            },
            .extent = .{
                .width = self.extent.width,
                .height = self.extent.height,
            },
        };

        self.vk_ctx.device.cmdSetScissor(
            cmd,
            0,
            1,
            @ptrCast(&scissor),
        );

        // Launch a draw command to draw 3 vertices.
        self.vk_ctx.device.cmdDraw(
            cmd,
            3,
            1,
            0,
            0,
        );

        // vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, _meshPipeline);
        self.vk_ctx.device.cmdBindPipeline(
            cmd,
            .graphics,
            self.mesh_pipeline,
        );

        // GPUDrawPushConstants push_constants;
        // push_constants.worldMatrix = glm::mat4{ 1.f };
        // push_constants.vertexBuffer = rectangle.vertexBufferAddress;
        const push_constants: GPUDrawPushConstants = .{
            .world_matrix = .{
                .{ 1.0, 0.0, 0.0, 0.0 },
                .{ 0.0, 1.0, 0.0, 0.0 },
                .{ 0.0, 0.0, 1.0, 0.0 },
                .{ 0.0, 0.0, 0.0, 1.0 },
            },
            .vertex_buffer = self.rectangle.vertex_buffer_address,
        };

        // vkCmdPushConstants(cmd, _meshPipelineLayout, VK_SHADER_STAGE_VERTEX_BIT, 0, sizeof(GPUDrawPushConstants), &push_constants);
        self.vk_ctx.device.cmdPushConstants(
            cmd,
            self.mesh_pipeline_layout,
            .{ .vertex_bit = true },
            0,
            @sizeOf(GPUDrawPushConstants),
            &push_constants,
        );
        // vkCmdBindIndexBuffer(cmd, rectangle.indexBuffer.buffer, 0, VK_INDEX_TYPE_UINT32);
        self.vk_ctx.device.cmdBindIndexBuffer(
            cmd,
            self.rectangle.index_buffer.handle,
            0,
            .uint32,
        );

        // vkCmdDrawIndexed(cmd, 6, 1, 0, 0, 0);
        self.vk_ctx.device.cmdDrawIndexed(
            cmd,
            6,
            1,
            0,
            0,
            0,
        );

        self.vk_ctx.device.cmdEndRendering(cmd);
    }
};

const std = @import("std");

const sdl = @import("sdl3");
const vk = @import("vulkan");
const zm = @import("zm");

const AllocatedImage = @import("./allocated_image.zig").AllocatedImage;
const AllocatedBuffer = @import("./allocated_buffer.zig").AllocatedBuffer;
const DescriptorAllocator = @import("./descriptors.zig").DescriptorAllocator;
const DescriptorLayoutBuilder = @import("./descriptors.zig").DescriptorLayoutBuilder;
const FrameData = @import("./frame_data.zig").FrameData;
const SwapChain = @import("./swap_chain.zig").SwapChain;
const VK_CTX = @import("./vk_ctx.zig").VK_CTX;
const vk_init = @import("./vk_initializers.zig");
const vkb = @import("./vk_bootstrap.zig");
const shaders = @import("./shaders.zig");
const ComputePushConstants = @import("./push_constants.zig").ComputePushConstants;
const ComputeEffect = @import("./compute_effect.zig").ComputeEffect;
const Vertex = @import("vk_types.zig").Vertex;
const GPUMeshBuffers = @import("vk_types.zig").GPUMeshBuffers;
const GPUDrawPushConstants = @import("vk_types.zig").GPUDrawPushConstants;
const IM_CTX = @import("./vk_ctx_im.zig").IM_CTX;
