//! Vulkan Context

pub const Renderer = struct {
    vk_ctx: VK_CTX,

    pub fn init(allocator: std.mem.Allocator, window: sdl.video.Window) !Renderer {
        var self: Renderer = undefined;

        self.vk_ctx = try VK_CTX.init(allocator, window);
        errdefer self.vk_ctx.deinit();
        std.log.debug("[Engine][Vulkan Context] Initialized successfully!", .{});

        return self;
    }

    pub fn deinit(self: Renderer) void {
        self.vk_ctx.deinit();
        std.log.debug("[Engine][Vulkan Context] Deinitialized successfully!", .{});
    }
};

const std = @import("std");
const sdl = @import("sdl3");
const vk = @import("vulkan");

const VK_CTX = @import("./vk_ctx.zig").VK_CTX;

// const vkb = @import("./vk_bootstrap.zig");
