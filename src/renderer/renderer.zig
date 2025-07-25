//! Vulkan Context

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    vk_ctx: *VK_CTX,
    swap_chain: SwapChain,

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

        return self;
    }

    pub fn deinit(self: Renderer) void {
        self.vk_ctx.device.deviceWaitIdle() catch @panic("Fuck");

        self.swap_chain.deinit();
        std.log.debug("[Engine][Vulkan][Swap Chain] Deinitialized successfully!", .{});

        self.vk_ctx.deinit();
        self.allocator.destroy(self.vk_ctx);
        std.log.debug("[Engine][Vulkan][Context] Deinitialized successfully!", .{});
    }
};

const std = @import("std");
const sdl = @import("sdl3");
const vk = @import("vulkan");

const VK_CTX = @import("./vk_ctx.zig").VK_CTX;
const SwapChain = @import("./swap_chain.zig").SwapChain;

const vk_init = @import("./vk_initializers.zig");
