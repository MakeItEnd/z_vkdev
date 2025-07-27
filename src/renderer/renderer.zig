//! Vulkan Context

pub const Renderer = struct {
    const FRAME_OVERLAP: usize = 2;

    allocator: std.mem.Allocator,
    vk_ctx: *VK_CTX,
    swap_chain: SwapChain,

    frames: [FRAME_OVERLAP]FrameData,
    frame_number: usize = 0,

    pub fn init(
        allocator: std.mem.Allocator,
        window: sdl.video.Window,
        extent: vk.Extent2D,
    ) !Renderer {
        var self: Renderer = undefined;
        self.allocator = allocator;

        self.vk_ctx = try self.allocator.create(VK_CTX);
        self.vk_ctx.* = try VK_CTX.init(self.allocator, window);
        errdefer self.vk_ctx.deinit();
        std.log.debug("[Engine][Vulkan][Context] Initialized successfully!", .{});

        self.swap_chain = try SwapChain.init(self.vk_ctx, extent);
        errdefer self.swap_chain.deinit();
        std.log.debug("[Engine][Vulkan][Swap Chain] Initialized successfully!", .{});

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

        // Make the swapchain image into writeable mode before rendering.
        image.transition(
            self.vk_ctx,
            cmd,
            .undefined,
            .general,
        );

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
        device.cmdClearColorImage(
            cmd,
            image.handle,
            .general,
            &clear_value,
            1,
            @ptrCast(&clear_range),
        );

        image.transition(
            self.vk_ctx,
            cmd,
            .general,
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

    fn get_current_frame(self: *Renderer) *FrameData {
        return &self.frames[self.frame_number % FRAME_OVERLAP];
    }
};

const std = @import("std");
const sdl = @import("sdl3");
const vk = @import("vulkan");

const VK_CTX = @import("./vk_ctx.zig").VK_CTX;
const SwapChain = @import("./swap_chain.zig").SwapChain;
const FrameData = @import("./frame_data.zig").FrameData;

const vk_init = @import("./vk_initializers.zig");
