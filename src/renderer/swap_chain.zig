//! A Vulkan Swap Chain

pub const SwapChain = struct {
    vk_ctx: *VK_CTX,

    handle: vk.SwapchainKHR,
    extent: vk.Extent2D,
    // image_format: vk.Format,
    // surface_format: vk.SurfaceFormatKHR,
    // present_mode: vk.PresentModeKHR,

    // images: []vk.Image,
    // views: []vk.ImageView,

    pub fn init(vk_ctx: *VK_CTX, extent: vk.Extent2D) !SwapChain {
        var self: SwapChain = undefined;
        self.vk_ctx = vk_ctx;
        std.log.debug("vk_ctx.* = {*}", .{self.vk_ctx});

        const swap_chain_support: SwapChainSupportDetails = try SwapChainSupportDetails.init(
            vk_ctx.allocator,
            &vk_ctx.instance,
            vk_ctx.physical_device,
            @enumFromInt(@intFromPtr(vk_ctx.surface.surface)),
        );
        defer swap_chain_support.deinit();

        const surface_format: vk.SurfaceFormatKHR = try swap_chain_support.pickSurfaceFormat();
        const present_mode: vk.PresentModeKHR = swap_chain_support.pickPresentMode();

        self.extent = choose_extent(
            swap_chain_support.capabilities,
            extent.width,
            extent.height,
        );

        var image_count: u32 = swap_chain_support.capabilities.min_image_count + 1;
        if (swap_chain_support.capabilities.max_image_count > 0 and image_count > swap_chain_support.capabilities.max_image_count) {
            image_count = swap_chain_support.capabilities.max_image_count;
        }

        var create_info: vk.SwapchainCreateInfoKHR = .{
            .surface = @enumFromInt(@intFromPtr(vk_ctx.surface.surface)),
            .min_image_count = image_count,
            .image_format = surface_format.format,
            .image_color_space = surface_format.color_space,
            .image_extent = self.extent,
            .image_array_layers = 1,
            .image_usage = vk.ImageUsageFlags{ .color_attachment_bit = true },
            .pre_transform = swap_chain_support.capabilities.current_transform,
            .composite_alpha = vk.CompositeAlphaFlagsKHR{ .opaque_bit_khr = true },
            .present_mode = present_mode,
            .clipped = vk.TRUE,
            .old_swapchain = .null_handle,
            .image_sharing_mode = undefined,
        };

        const indices: QueueFamilyIndices = try QueueFamilyIndices.find(
            vk_ctx.allocator,
            &vk_ctx.instance,
            vk_ctx.physical_device,
            @enumFromInt(@intFromPtr(vk_ctx.surface.surface)),
        );

        if (indices.graphics_family != indices.present_family) {
            create_info.image_sharing_mode = vk.SharingMode.concurrent;
            create_info.queue_family_index_count = 2;
            create_info.p_queue_family_indices = &.{ indices.graphics_family.?, indices.present_family.? };
        } else {
            create_info.image_sharing_mode = vk.SharingMode.exclusive;
            create_info.queue_family_index_count = 0;
            create_info.p_queue_family_indices = null;
        }

        self.handle = vk_ctx.device.createSwapchainKHR(&create_info, vk_ctx.vk_allocator) catch {
            return error.SwapchainCreationFailed;
        };
        errdefer vk_ctx.device.destroySwapchainKHR(self.handle, vk_ctx.vk_allocator);

        // if (old_handle != .null_handle) {
        //     // Apparently, the old swapchain handle still needs to be destroyed after recreating.
        //     vk_ctx.device.destroySwapchainKHR(old_handle, null);
        // }

        return self;
    }

    pub fn deinitExceptHandle(self: SwapChain) void {
        // for (self.swap_images) |si| si.deinit(self.gc);
        // self.allocator.free(self.swap_images);
        self.vk_ctx.device.destroySemaphore(self.next_image_acquired, null);
    }

    pub fn deinit(self: SwapChain) void {
        if (self.handle == .null_handle) return;

        self.vk_ctx.device.destroySwapchainKHR(
            self.handle,
            self.vk_ctx.vk_allocator,
        );
    }

    fn choose_extent(
        capabilities: vk.SurfaceCapabilitiesKHR,
        width: u32,
        height: u32,
    ) vk.Extent2D {
        if (capabilities.current_extent.width != std.math.maxInt(u32)) {
            return capabilities.current_extent;
        } else {
            // TODO: Check if I should get the framebuffer size from the window here.
            return vk.Extent2D{
                .width = std.math.clamp(
                    width,
                    capabilities.min_image_extent.width,
                    capabilities.max_image_extent.width,
                ),
                .height = std.math.clamp(
                    height,
                    capabilities.min_image_extent.height,
                    capabilities.max_image_extent.height,
                ),
            };
        }
    }
};

const SwapChainSupportDetails = struct {
    allocator: std.mem.Allocator,
    capabilities: vk.SurfaceCapabilitiesKHR,

    surface_formats: []vk.SurfaceFormatKHR,
    present_modes: []vk.PresentModeKHR,

    pub fn init(
        allocator: std.mem.Allocator,
        instance: *vk.InstanceProxy,
        physical_device: vk.PhysicalDevice,
        surface: vk.SurfaceKHR,
    ) !SwapChainSupportDetails {
        var self: SwapChainSupportDetails = undefined;
        self.allocator = allocator;

        // TODO: Check if should use getPhysicalDeviceSurfaceCapabilities2KHR
        self.capabilities = try instance.getPhysicalDeviceSurfaceCapabilitiesKHR(
            physical_device,
            surface,
        );

        // TODO: Check if should use getPhysicalDeviceSurfaceFormatsAlloc2KHR
        self.surface_formats = try instance.getPhysicalDeviceSurfaceFormatsAllocKHR(
            physical_device,
            surface,
            allocator,
        );

        // TODO: Check if should use getPhysicalDeviceSurfacePresentModes2KHR
        self.present_modes = try instance.getPhysicalDeviceSurfacePresentModesAllocKHR(
            physical_device,
            surface,
            allocator,
        );

        return self;
    }

    pub fn deinit(self: SwapChainSupportDetails) void {
        self.allocator.free(self.surface_formats);
        self.allocator.free(self.present_modes);
    }

    pub fn pickSurfaceFormat(self: *const SwapChainSupportDetails) !vk.SurfaceFormatKHR {
        for (self.surface_formats) |surface_format| {
            if (surface_format.format == vk.Format.b8g8r8a8_unorm and surface_format.color_space == vk.ColorSpaceKHR.srgb_nonlinear_khr) {
                return surface_format;
            }
        }

        return error.ExpectedSurfaceFormatNotSupported;
    }

    pub fn pickPresentMode(self: *const SwapChainSupportDetails) vk.PresentModeKHR {
        for (self.present_modes) |present_mode| {
            if (present_mode == vk.PresentModeKHR.fifo_khr) {
                return present_mode;
            }
        }

        return vk.PresentModeKHR.fifo_khr;
    }
};

const SwapImage = struct {
    image: vk.Image,
    view: vk.ImageView,
    image_acquired: vk.Semaphore,
    render_finished: vk.Semaphore,
    frame_fence: vk.Fence,

    fn init(vk_ctx: *const VK_CTX, image: vk.Image, format: vk.Format) !SwapImage {
        const view = try vk_ctx.device.createImageView(&.{
            .image = image,
            .view_type = .@"2d",
            .format = format,
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        }, null);
        errdefer vk_ctx.device.destroyImageView(view, null);

        const image_acquired = try vk_ctx.device.createSemaphore(&.{}, null);
        errdefer vk_ctx.device.destroySemaphore(image_acquired, null);

        const render_finished = try vk_ctx.device.createSemaphore(&.{}, null);
        errdefer vk_ctx.device.destroySemaphore(render_finished, null);

        const frame_fence = try vk_ctx.device.createFence(&.{ .flags = .{ .signaled_bit = true } }, null);
        errdefer vk_ctx.device.destroyFence(frame_fence, null);

        return SwapImage{
            .image = image,
            .view = view,
            .image_acquired = image_acquired,
            .render_finished = render_finished,
            .frame_fence = frame_fence,
        };
    }

    fn deinit(self: SwapImage, vk_ctx: *const VK_CTX) void {
        self.waitForFence(vk_ctx) catch return;

        vk_ctx.device.destroyImageView(self.view, null);
        vk_ctx.device.destroySemaphore(self.image_acquired, null);
        vk_ctx.device.destroySemaphore(self.render_finished, null);
        vk_ctx.device.destroyFence(self.frame_fence, null);
    }

    fn waitForFence(self: SwapImage, vk_ctx: *const VK_CTX) !void {
        _ = try vk_ctx.device.waitForFences(
            1,
            @ptrCast(&self.frame_fence),
            vk.TRUE,
            std.math.maxInt(u64),
        );
    }
};

const std = @import("std");
const sdl = @import("sdl3");
const vk = @import("vulkan");

const vkb = @import("./vk_bootstrap.zig");
const VK_CTX = @import("./vk_ctx.zig").VK_CTX;
const QueueFamilyIndices = vkb.QueueFamilyIndices;
