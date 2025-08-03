//! Vulkan Graphix Context
//!
//! The vulkan VK_CTX will initialize:
//! 1. Vulkan Instance
//! 2. Vulkan Debug Messenger (If required)
//! 3. A rendering surface
//! 4. Pick a Physical Device
//! 5. Create a Logical Device
//! 6. Create the required Queues
//! 6. Create VMA instance

pub const VK_CTX = struct {
    const ENABLE_VALIDATION_LAYERS: bool = @import("builtin").mode == .Debug;

    allocator: std.mem.Allocator,
    vma: zig_vma.VulkanMemoryAllocator,

    vkbw: vk.BaseWrapper,

    instance: vk.InstanceProxy,
    debug_messenger: vk.DebugUtilsMessengerEXT = .null_handle,

    surface: sdl.vulkan.Surface,

    physical_device: vk.PhysicalDevice = .null_handle,
    device: vk.DeviceProxy,

    graphics_queue: Queue,

    pub fn init(allocator: std.mem.Allocator, window: sdl.video.Window) !VK_CTX {
        var self: VK_CTX = undefined;

        self.allocator = allocator;

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
        errdefer self.instance.destroyInstance(null);
        self.debug_messenger = vkb_instance.debug_messenger;
        std.log.debug("[Engine][Vulkan][Instance] Initialized successfully!", .{});

        self.surface = try sdl.vulkan.Surface.init(
            window,
            // ! I'm 99% sure the below cast isn't correct
            @ptrFromInt(@intFromEnum(self.instance.handle)),
            null,
        );
        std.log.debug("[Engine][Vulkan][Surface] Initialized successfully!", .{});

        self.physical_device = try vkb.PhysicalDeviceSelector.new(
            self.allocator,
            &self.instance,
            @enumFromInt(@intFromPtr(self.surface.surface)),
        ).pick();
        std.log.debug("[Engine][Vulkan][Physical Device] Selected!", .{});

        self.device = try vkb.DeviceBuilder.new(
            self.allocator,
            &self.instance,
            self.physical_device,
            @enumFromInt(@intFromPtr(self.surface.surface)),
        ).build();
        errdefer self.device.destroyDevice(null);
        std.log.debug("[Engine][Vulkan][Device] Initialized successfully!", .{});

        const queue_family_indices: vkb.QueueFamilyIndices = try vkb.QueueFamilyIndices.find(
            self.allocator,
            &self.instance,
            self.physical_device,
            @enumFromInt(@intFromPtr(self.surface.surface)),
        );
        self.graphics_queue = Queue.init(
            &self.device,
            queue_family_indices.graphics_family.?,
        );
        std.log.debug("[Engine][Vulkan][Queue][Graphics] Initialized successfully!", .{});

        const vulkan_f = zig_vma.VulkanFunctions{
            .vkGetInstanceProcAddr = self.vkbw.dispatch.vkGetInstanceProcAddr.?,
            .vkGetDeviceProcAddr = self.instance.wrapper.dispatch.vkGetDeviceProcAddr.?,
        };
        self.vma = try zig_vma.VulkanMemoryAllocator.init(&.{
            .physical_device = self.physical_device,
            .device = self.device.handle,
            .p_vulkan_functions = @ptrCast(&vulkan_f),
            .instance = self.instance.handle,
            .vulkan_api_version = @bitCast(vk.API_VERSION_1_4),
            .flags = .{
                .buffer_device_address_bit = true,
            },
        });
        std.log.debug("[Engine][Vulkan][Vulkan Memory Allocator] Initialized successfully!", .{});

        return self;
    }

    pub fn deinit(self: VK_CTX) void {
        self.vma.deinit();
        std.log.debug("[Engine][Vulkan][Vulkan Memory Allocator] Destroyed successfully!", .{});

        self.surface.deinit();
        std.log.debug("[Engine][Vulkan][Surface] Destroyed successfully!", .{});

        self.device.destroyDevice(null);
        std.log.debug("[Engine][Vulkan][Device] Destroyed successfully!", .{});

        if (ENABLE_VALIDATION_LAYERS) {
            self.instance.destroyDebugUtilsMessengerEXT(self.debug_messenger, null);
        }

        self.instance.destroyInstance(null);
        std.log.debug("[Engine][Vulkan][Instace] Destroyed successfully!", .{});

        // Don't forget to free the tables to prevent a memory leak.
        self.allocator.destroy(self.device.wrapper);
        self.allocator.destroy(self.instance.wrapper);
        std.log.debug("[Engine][Vulkan] Deinitialized successfully!", .{});
    }
};

pub const Queue = struct {
    handle: vk.Queue,
    family: u32,

    fn init(device: *vk.DeviceProxy, family: u32) Queue {
        return .{
            .handle = device.getDeviceQueue(family, 0),
            .family = family,
        };
    }
};

const std = @import("std");
const sdl = @import("sdl3");
const vk = @import("vulkan");
const zig_vma = @import("zig_vma");

const vkb = @import("./vk_bootstrap.zig");
