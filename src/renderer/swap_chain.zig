//! A Vulkan Swap Chain

pub const SwapChain = struct {
    vk_ctx: *VK_CTX, // ! TODO: Check if it should hold this or just pass it down when needen

    handle: vk.SwapchainKHR,
    extent: vk.Extent2D,
    swap_images: []SwapChainImage,

    pub fn init(vk_ctx: *VK_CTX, extent: vk.Extent2D) !SwapChain {
        var self: SwapChain = undefined;
        self.vk_ctx = vk_ctx;

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
            .image_usage = vk.ImageUsageFlags{
                .color_attachment_bit = true,
                .transfer_dst_bit = true,
            },
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

        self.swap_images = try initSwapchainImages(
            vk_ctx,
            self.handle,
            surface_format.format,
            self.vk_ctx.allocator,
        );
        errdefer {
            for (self.swap_images) |si| si.deinit(vk_ctx);

            self.vk_ctx.allocator.free(self.swap_images);
        }
        std.log.debug("[Engine][Vulkan][Swap Chain][Swap Images] Initialized successfully!", .{});

        return self;
    }

    pub fn deinitExceptHandle(self: SwapChain) void {
        for (self.swap_images) |si| si.deinit(self.vk_ctx);
        self.vk_ctx.allocator.free(self.swap_images);
        std.log.debug("[Engine][Vulkan][Swap Chain][Swap Images] Deinitialized successfully!", .{});

        // self.vk_ctx.device.destroySemaphore(self.next_image_acquired, null);
    }

    pub fn deinit(self: SwapChain) void {
        if (self.handle == .null_handle) return;

        self.deinitExceptHandle();

        self.vk_ctx.device.destroySwapchainKHR(
            self.handle,
            self.vk_ctx.vk_allocator,
        );
    }

    pub fn next_image_index(self: *const SwapChain, semaphore: vk.Semaphore, fence: vk.Fence) !u32 {
        const ani_result = try self.vk_ctx.device.acquireNextImageKHR(
            self.handle,
            1_000_000_000,
            semaphore,
            fence,
        );

        if (ani_result.result != .success) {
            return error.CouldNotRetrieveSwapChainNextImageIndex;
        }

        return ani_result.image_index;
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

    fn initSwapchainImages(
        vk_ctx: *const VK_CTX,
        swapchain: vk.SwapchainKHR,
        format: vk.Format,
        allocator: std.mem.Allocator,
    ) ![]SwapChainImage {
        const images = try vk_ctx.device.getSwapchainImagesAllocKHR(
            swapchain,
            allocator,
        );
        defer allocator.free(images);

        const swap_images = try allocator.alloc(SwapChainImage, images.len);
        errdefer allocator.free(swap_images);

        var i: usize = 0;
        errdefer for (swap_images[0..i]) |si| si.deinit(vk_ctx);

        for (images) |image| {
            swap_images[i] = try SwapChainImage.init(vk_ctx, image, format);
            i += 1;
        }

        return swap_images;
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

const std = @import("std");
const sdl = @import("sdl3");
const vk = @import("vulkan");

const vkb = @import("./vk_bootstrap.zig");
const VK_CTX = @import("./vk_ctx.zig").VK_CTX;
const QueueFamilyIndices = vkb.QueueFamilyIndices;
const SwapChainImage = @import("./swap_chain_image.zig").SwapChainImage;
