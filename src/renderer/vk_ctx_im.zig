//! Immediate Mode Rendering Context
//!
//! Used to draw outside the game loop by sending commands to the GPU
//! without syncronizing with swapchain or with rendering logic.

pub const IM_CTX = struct {
    // Immediate submit structures.
    fence: vk.Fence,
    command_buffer: vk.CommandBuffer,
    command_pool: vk.CommandPool,

    /// Initialize the data required for Immediate Mode.
    pub fn init(vk_ctx: *VK_CTX) !IM_CTX {
        var self: IM_CTX = undefined;

        self.command_pool = try vk_ctx.device.createCommandPool(
            &.{
                .flags = .{
                    .reset_command_buffer_bit = true,
                },
                .queue_family_index = vk_ctx.graphics_queue.family,
            },
            null,
        );

        try vk_ctx.device.allocateCommandBuffers(
            &.{
                .command_pool = self.command_pool,
                .level = .primary,
                .command_buffer_count = 1,
            },
            @ptrCast(&self.command_buffer),
        );

        self.fence = try vk_ctx.device.createFence(
            &.{
                .flags = .{
                    .signaled_bit = true,
                },
            },
            null,
        );

        return self;
    }

    pub fn deinit(self: IM_CTX, vk_ctx: *VK_CTX) void {
        vk_ctx.device.destroyCommandPool(
            self.command_pool,
            null,
        );

        vk_ctx.device.destroyFence(
            self.fence,
            null,
        );
    }

    pub fn submit_begin(
        self: *IM_CTX,
        vk_ctx: *VK_CTX,
    ) !vk.CommandBuffer {
        try vk_ctx.device.resetFences(
            1,
            @ptrCast(&self.fence),
        );

        const cmd: vk.CommandBuffer = self.command_buffer;
        try vk_ctx.device.resetCommandBuffer(cmd, .{});

        try vk_ctx.device.beginCommandBuffer(
            cmd,
            &.{
                .flags = .{
                    .one_time_submit_bit = true,
                },
            },
        );

        return cmd;
    }

    pub fn submit_end(
        self: *IM_CTX,
        vk_ctx: *VK_CTX,
        cmd: vk.CommandBuffer,
    ) !void {
        try vk_ctx.device.endCommandBuffer(cmd);

        const submit_info: vk.SubmitInfo2 = vk_init.submit_info(
            &.{
                .command_buffer = cmd,
                .device_mask = 0,
            },
            null,
            null,
        );

        try vk_ctx.device.queueSubmit2(
            vk_ctx.graphics_queue.handle,
            1,
            @ptrCast(&submit_info),
            self.fence,
        );

        _ = try vk_ctx.device.waitForFences(
            1,
            @ptrCast(&self.fence),
            vk.TRUE,
            9_999_999_999,
        );
    }
};

const std = @import("std");
const vk = @import("vulkan");

const VK_CTX = @import("vk_ctx.zig").VK_CTX;
const vk_init = @import("./vk_initializers.zig");
