//! Vulkan Graphix Context
//!
//! The vulkan VK_CTX will initialize:
//! 1. Vulkan Instance
//! 2. Vulkan Debug Messenger (If required)
//! 3. A rendering surface
//! 4. Pick a Physical Device
//! 5. Create a Logical Device
//! 6. Create the required Queues

pub const VK_CTX = struct {
    const ENABLE_VALIDATION_LAYERS: bool = @import("builtin").mode == .Debug;

    allocator: std.mem.Allocator,
    vk_allocator: ?*const vk.AllocationCallbacks,

    vkbw: vk.BaseWrapper,

    instance: vk.InstanceProxy,
    debug_messenger: vk.DebugUtilsMessengerEXT = .null_handle,

    surface: sdl.vulkan.Surface,

    physical_device: vk.PhysicalDevice = .null_handle,
    device: vk.DeviceProxy,

    // graphics_queue: vk.Queue,

    pub fn init(allocator: std.mem.Allocator, window: sdl.video.Window) !VK_CTX {
        var self: VK_CTX = undefined;

        self.allocator = allocator;
        self.vk_allocator = null;

        self.vkbw = vk.BaseWrapper.load(@as(
            vk.PfnGetInstanceProcAddr,
            @ptrCast(try sdl.vulkan.getVkGetInstanceProcAddr()),
        ));
        std.log.debug("[Vulkan][Base Wrapper] Initialized successfully!", .{});

        const vkb_instance =
            try vkb.InstanceBuilder.new(
                self.allocator,
                &self.vkbw,
                ENABLE_VALIDATION_LAYERS,
            ).build();

        self.instance = vkb_instance.instance_proxy;
        errdefer self.instance.destroyInstance(self.vk_allocator);
        self.debug_messenger = vkb_instance.debug_messenger;
        std.log.debug("[Engine][Vulkan][Instance] Initialized successfully!", .{});

        self.surface = try sdl.vulkan.Surface.init(
            window,
            // ! I'm 99% sure the below cast isn't correct
            @ptrFromInt(@intFromEnum(self.instance.handle)),
            @ptrCast(self.vk_allocator),
        );
        std.log.debug("[Engine][Vulkan][Surface] Initialized successfully!", .{});

        self.physical_device = try vkb.PhysicalDeviceSelector.new(
            self.allocator,
            &self.instance,
        ).pick();
        std.log.debug("[Engine][Vulkan][Physical Device] Selected!", .{});

        self.device = try vkb.DeviceBuilder.new(
            self.allocator,
            &self.instance,
            self.physical_device,
        ).build();
        errdefer self.device.destroyDevice(self.vk_allocator);
        std.log.debug("[Engine][Vulkan][Device] Initialized successfully!", .{});

        return self;
    }

    pub fn deinit(self: VK_CTX) void {
        self.surface.deinit();
        std.log.debug("[Engine][Vulkan][Surface] Destroyed successfully!", .{});

        self.device.destroyDevice(self.vk_allocator);
        std.log.debug("[Engine][Vulkan][Device] Destroyed successfully!", .{});

        if (ENABLE_VALIDATION_LAYERS) {
            self.instance.destroyDebugUtilsMessengerEXT(self.debug_messenger, self.vk_allocator);
        }

        self.instance.destroyInstance(self.vk_allocator);
        std.log.debug("[Engine][Vulkan][Instace] Destroyed successfully!", .{});

        // Don't forget to free the tables to prevent a memory leak.
        self.allocator.destroy(self.device.wrapper);
        self.allocator.destroy(self.instance.wrapper);
        std.log.debug("[Engine][Vulkan] Deinitialized successfully!", .{});
    }
};

const std = @import("std");
const sdl = @import("sdl3");
const vk = @import("vulkan");

const vkb = @import("./vk_bootstrap.zig");
