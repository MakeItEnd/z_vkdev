//! Frame data

pub const FrameData = struct {
    commandPool: vk.CommandPool,
    mainCommandBuffer: vk.CommandBuffer,
    swapchain_semaphore: vk.Semaphore,
    // render_semaphore: vk.Semaphore, // ! TODO: Might not be needed anymre as we use a per image one.
    render_fence: vk.Fence,

    pub fn init(vk_ctx: *VK_CTX) !FrameData {
        var self: FrameData = undefined;

        try self.init_sync_structures(vk_ctx);
        try self.init_commands(vk_ctx);

        return self;
    }

    pub fn deinit(self: FrameData, vk_ctx: *VK_CTX) void {
        vk_ctx.device.destroyCommandPool(
            self.commandPool,
            vk_ctx.vk_allocator,
        );

        vk_ctx.device.destroyFence(
            self.render_fence,
            vk_ctx.vk_allocator,
        );
        // vk_ctx.device.destroySemaphore(
        //     self.render_semaphore,
        //     vk_ctx.vk_allocator,
        // );
        vk_ctx.device.destroySemaphore(
            self.swapchain_semaphore,
            vk_ctx.vk_allocator,
        );
    }

    fn init_sync_structures(self: *FrameData, vk_ctx: *VK_CTX) !void {
        // Create syncronization structures.
        // One fence to control when the GPU has finished rendering the frame,
        // and 2 semaphores to syncronize rendering with swapchain
        // we want the fence to start signalled so we can wait on it on the first frame.

        const fence_create_info: vk.FenceCreateInfo = .{
            .flags = .{
                .signaled_bit = true,
            },
        };
        const semaphore_create_info: vk.SemaphoreCreateInfo = .{};

        self.render_fence = try vk_ctx.device.createFence(
            &fence_create_info,
            vk_ctx.vk_allocator,
        );

        self.swapchain_semaphore = try vk_ctx.device.createSemaphore(
            &semaphore_create_info,
            vk_ctx.vk_allocator,
        );
        // self.render_semaphore = try vk_ctx.device.createSemaphore(
        //     &semaphore_create_info,
        //     vk_ctx.vk_allocator,
        // );
    }

    fn init_commands(self: *FrameData, vk_ctx: *VK_CTX) !void {
        // Create a command pool for commands submitted to the graphics queue.
        // We also want the pool to allow for resetting of individual command buffers.

        const command_poool_info: vk.CommandPoolCreateInfo = .{
            .flags = .{
                .reset_command_buffer_bit = true,
            },
            .queue_family_index = vk_ctx.graphics_queue.family,
        };

        self.commandPool = try vk_ctx.device.createCommandPool(
            &command_poool_info,
            vk_ctx.vk_allocator,
        );

        // Allocate the default command buffer that we will use for rendering.
        const cmdAllocInfo: vk.CommandBufferAllocateInfo = .{
            .command_pool = self.commandPool,
            .level = .primary,
            .command_buffer_count = 1,
        };

        try vk_ctx.device.allocateCommandBuffers(
            &cmdAllocInfo,
            @ptrCast(&self.mainCommandBuffer),
        );
    }
};

const std = @import("std");
const vk = @import("vulkan");
const VK_CTX = @import("./vk_ctx.zig").VK_CTX;
