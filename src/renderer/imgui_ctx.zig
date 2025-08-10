//! C Imgui Context

fn check_vk(result: c.VkResult) callconv(.c) void {
    const res: vk.Result = @enumFromInt(@as(i32, @bitCast(result)));

    std.log.debug("check_vk :: res :: {any}", .{res});
}

pub const Imgui_CTX = struct {
    /// This is the parameters in reverse of `PfnGetDeviceProcAddr`
    /// how Imgui expects them for the loader...
    handle: ?*c.ImGuiContext,
    pool: vk.DescriptorPool,

    pub fn init(
        vk_ctx: *VK_CTX,
        window: sdl.video.Window,
        image_format: vk.Format,
    ) !Imgui_CTX {
        // * Set global reference to load pointers.
        g_vk_ctx = vk_ctx;

        var self: Imgui_CTX = undefined;

        // 1: Create descriptor pool for IMGUI.
        // The size of the pool is very oversize, but it's copied from imgui demo itself.

        // const pool_sizes: []const vk.DescriptorPoolSize = &[_]vk.DescriptorPoolSize{
        //     .{ .type = .sampler, .descriptor_count = 1_000 },
        //     .{ .type = .combined_image_sampler, .descriptor_count = 1_000 },
        //     .{ .type = .sampled_image, .descriptor_count = 1_000 },
        //     .{ .type = .storage_image, .descriptor_count = 1_000 },
        //     .{ .type = .uniform_texel_buffer, .descriptor_count = 1_000 },
        //     .{ .type = .storage_texel_buffer, .descriptor_count = 1_000 },
        //     .{ .type = .uniform_buffer, .descriptor_count = 1_000 },
        //     .{ .type = .storage_buffer, .descriptor_count = 1_000 },
        //     .{ .type = .uniform_buffer_dynamic, .descriptor_count = 1_000 },
        //     .{ .type = .storage_buffer_dynamic, .descriptor_count = 1_000 },
        //     .{ .type = .input_attachment, .descriptor_count = 1_000 },
        // };
        const pool_sizes: []const vk.DescriptorPoolSize = &[_]vk.DescriptorPoolSize{
            .{
                .type = .combined_image_sampler,
                .descriptor_count = @intCast(c.IMGUI_IMPL_VULKAN_MINIMUM_IMAGE_SAMPLER_POOL_SIZE),
            },
        };

        const pool_info: vk.DescriptorPoolCreateInfo = .{
            .flags = .{
                .free_descriptor_set_bit = true,
            },
            .max_sets = 1_000,
            .pool_size_count = @intCast(pool_sizes.len),
            .p_pool_sizes = @ptrCast(pool_sizes.ptr),
        };

        self.pool = try vk_ctx.device.createDescriptorPool(
            &pool_info,
            null,
        );

        // 2: Initialize imgui library.
        // var shared_font_atlas: ?c.ImFontAtlas = null;
        self.handle = c.ImGui_CreateContext(null);
        if (self.handle == null) {
            return error.FailedToRetrieveImguiContext;
        }

        if (!c.cImGui_ImplSDL3_InitForVulkan(@ptrCast(window.value))) {
            return error.FailedToInitializeImgui;
        }

        if (!c.cImGui_ImplVulkan_LoadFunctions(
            @bitCast(vk.API_VERSION_1_4),
            @ptrCast(&vkLoader),
        )) {
            return error.FailedToLoadVulkanFunctionsForImgui;
        }
        std.log.debug(">>>> [IMGUI][VK LOADER] SET! {any}", .{vk_ctx.physical_device});

        g_instance = try vk_ctx.allocator.create(vk.Instance);
        g_instance.* = vk_ctx.instance.handle;

        var vk_init_info: c.ImGui_ImplVulkan_InitInfo = .{
            .Instance = @ptrCast(g_instance),
            .PhysicalDevice = @constCast(@ptrCast(&vk_ctx.physical_device)),
            .Device = @ptrCast(&vk_ctx.device.handle),
            .Queue = @ptrCast(&vk_ctx.graphics_queue.handle),
            .DescriptorPool = @ptrCast(&self.pool),
            .DescriptorPoolSize = 0,
            .MinImageCount = 3,
            .ImageCount = 3,
            .UseDynamicRendering = true,
            .PipelineRenderingCreateInfo = @bitCast(vk.PipelineRenderingCreateInfo{
                .view_mask = 0,
                .color_attachment_count = 1,
                .p_color_attachment_formats = @ptrCast(&image_format),
                .depth_attachment_format = .undefined,
                .stencil_attachment_format = .undefined,
            }),
            .MSAASamples = vk.SampleCountFlags.toInt(.{
                .@"1_bit" = true,
            }),
            .Allocator = @ptrCast(&vk_ctx.vma.handle),
        };

        std.log.debug(">>>> [IMGUI][cImGui_ImplVulkan_Init] BEFORE!", .{});
        if (!c.cImGui_ImplVulkan_Init(@ptrCast(&vk_init_info))) {
            return error.FailedToInitializeVulkanForImgui;
        }
        std.log.debug(">>>> [IMGUI][cImGui_ImplVulkan_Init] AFTER!", .{});

        // ImGui_ImplVulkan_CreateFontsTexture();

        return self;
    }

    pub fn deinit(self: Imgui_CTX, vk_ctx: *VK_CTX) void {
        vk_ctx.allocator.destroy(g_instance);

        c.cImGui_ImplVulkan_Shutdown();
        c.cImGui_ImplSDL3_Shutdown();
        // c.ImGui_DestroyContext(self.handle);

        vk_ctx.device.destroyDescriptorPool(self.pool, null);
    }

    pub fn process_event(self: *const Imgui_CTX, event: sdl.events.Event) void {
        _ = self;

        _ = c.cImGui_ImplSDL3_ProcessEvent(@ptrCast(&event.toSdl()));
    }

    pub fn draw(self: *const Imgui_CTX) void {
        _ = self;

        c.cImGui_ImplVulkan_NewFrame();
        c.cImGui_ImplSDL3_NewFrame();
        c.ImGui_NewFrame();

        var show_window: bool = true;
        c.ImGui_ShowDemoWindow(@ptrCast(&show_window));

        c.ImGui_Render();
    }

    pub fn vulkan_draw(
        self: *const Imgui_CTX,
        vk_ctx: *VK_CTX,
        cmd: vk.CommandBuffer,
        target_image_view: vk.ImageView,
        extent: vk.Extent2D,
    ) void {
        _ = self;

        var color_attachment: vk.RenderingAttachmentInfo = vk_init.attachment_info(
            target_image_view,
            null,
            .color_attachment_optimal,
        );
        const render_info: vk.RenderingInfo = vk_init.rendering_info(
            extent,
            &color_attachment,
            null,
        );

        vk_ctx.device.cmdBeginRendering(cmd, &render_info);

        c.cImGui_ImplVulkan_RenderDrawData(
            c.ImGui_GetDrawData(),
            @constCast(@ptrCast(&cmd)),
        );

        vk_ctx.device.cmdEndRendering(cmd);
    }
};

var g_vk_ctx: *VK_CTX = undefined;
var g_instance: *vk.Instance = undefined;

pub fn vkLoader(
    p_name: [*c]const u8,
    p_instance: ?*anyopaque,
) callconv(.C) ?*const fn () callconv(.C) void {
    const vkGetInstanceProcAddr: vk.PfnGetInstanceProcAddr = @ptrCast(g_vk_ctx.vkbw.dispatch.vkGetInstanceProcAddr.?);

    // const inst: ?*vk.Instance = @ptrCast(@alignCast(instance));
    const name: []const u8 = std.mem.span(p_name);
    std.log.debug("self.instance: {any}, p_inst: {any}, p_name: {any}, name: {s}", .{
        g_vk_ctx.instance.handle,
        p_instance,
        p_name,
        name,
    });

    if (std.mem.eql(u8, "vkGetPhysicalDeviceProperties", name)) {
        return @ptrCast(&myVkGetPhysicalDeviceProperties);
    } else if (std.mem.eql(u8, "vkAllocateCommandBuffers", name)) {
        return @ptrCast(&myVkAllocateCommandBuffers);
    } else if (std.mem.eql(u8, "vkAllocateDescriptorSets", name)) {
        return @ptrCast(&myVkAllocateDescriptorSets);
    } else if (std.mem.eql(u8, "vkAllocateMemory", name)) {
        return @ptrCast(&myVkAllocateMemory);
    } else if (std.mem.eql(u8, "vkBeginCommandBuffer", name)) {
        return @ptrCast(&myVkBeginCommandBuffer);
    } else if (std.mem.eql(u8, "vkBindBufferMemory", name)) {
        return @ptrCast(&myVkBindBufferMemory);
    } else if (std.mem.eql(u8, "vkBindImageMemory", name)) {
        return @ptrCast(&myVkBindImageMemory);
    } else if (std.mem.eql(u8, "vkCmdBindDescriptorSets", name)) {
        return @ptrCast(&myVkCmdBindDescriptorSets);
    } else if (std.mem.eql(u8, "vkCmdBindIndexBuffer", name)) {
        return @ptrCast(&myVkCmdBindIndexBuffer);
    } else if (std.mem.eql(u8, "vkCmdBindPipeline", name)) {
        return @ptrCast(&myVkCmdBindPipeline);
    } else if (std.mem.eql(u8, "vkCmdBindVertexBuffers", name)) {
        return @ptrCast(&myVkCmdBindVertexBuffers);
    } else if (std.mem.eql(u8, "vkCmdCopyBufferToImage", name)) {
        return @ptrCast(&myVkCmdCopyBufferToImage);
    } else if (std.mem.eql(u8, "vkCmdDrawIndexed", name)) {
        return @ptrCast(&myVkCmdDrawIndexed);
    } else if (std.mem.eql(u8, "vkCmdPipelineBarrier", name)) {
        return @ptrCast(&myVkCmdPipelineBarrier);
    } else if (std.mem.eql(u8, "vkCmdPushConstants", name)) {
        return @ptrCast(&myVkCmdPushConstants);
    } else if (std.mem.eql(u8, "vkCmdSetScissor", name)) {
        return @ptrCast(&myVkCmdSetScissor);
    } else if (std.mem.eql(u8, "vkCmdSetViewport", name)) {
        return @ptrCast(&myVkCmdSetViewport);
    } else if (std.mem.eql(u8, "vkCreateBuffer", name)) {
        return @ptrCast(&myVkCreateBuffer);
    } else if (std.mem.eql(u8, "vkCreateCommandPool", name)) {
        return @ptrCast(&myVkCreateCommandPool);
    } else if (std.mem.eql(u8, "vkCreateDescriptorPool", name)) {
        return @ptrCast(&myVkCreateDescriptorPool);
    } else if (std.mem.eql(u8, "vkCreateDescriptorSetLayout", name)) {
        return @ptrCast(&myVkCreateDescriptorSetLayout);
    } else if (std.mem.eql(u8, "vkCreateFence", name)) {
        return @ptrCast(&myVkCreateFence);
    } else if (std.mem.eql(u8, "vkCreateFramebuffer", name)) {
        return @ptrCast(&myVkCreateFramebuffer);
    } else if (std.mem.eql(u8, "vkCreateGraphicsPipelines", name)) {
        return @ptrCast(&myVkCreateGraphicsPipelines);
    } else if (std.mem.eql(u8, "vkCreateImage", name)) {
        return @ptrCast(&myVkCreateImage);
    } else if (std.mem.eql(u8, "vkCreateImageView", name)) {
        return @ptrCast(&myVkCreateImageView);
    } else if (std.mem.eql(u8, "vkCreatePipelineLayout", name)) {
        return @ptrCast(&myVkCreatePipelineLayout);
    } else if (std.mem.eql(u8, "vkCreateRenderPass", name)) {
        return @ptrCast(&myVkCreateRenderPass);
    } else if (std.mem.eql(u8, "vkCreateSampler", name)) {
        return @ptrCast(&myVkCreateSampler);
    } else if (std.mem.eql(u8, "vkCreateSemaphore", name)) {
        return @ptrCast(&myVkCreateSemaphore);
    } else if (std.mem.eql(u8, "vkCreateShaderModule", name)) {
        return @ptrCast(&myVkCreateShaderModule);
    } else if (std.mem.eql(u8, "vkCreateSwapchainKHR", name)) {
        return @ptrCast(&myVkCreateSwapchainKHR);
    } else if (std.mem.eql(u8, "vkDestroyBuffer", name)) {
        return @ptrCast(&myVkDestroyBuffer);
    } else if (std.mem.eql(u8, "vkDestroyCommandPool", name)) {
        return @ptrCast(&myVkDestroyCommandPool);
    } else if (std.mem.eql(u8, "vkDestroyDescriptorPool", name)) {
        return @ptrCast(&myVkDestroyDescriptorPool);
    } else if (std.mem.eql(u8, "vkDestroyDescriptorSetLayout", name)) {
        return @ptrCast(&myVkDestroyDescriptorSetLayout);
    } else if (std.mem.eql(u8, "vkDestroyFence", name)) {
        return @ptrCast(&myVkDestroyFence);
    } else if (std.mem.eql(u8, "vkDestroyFramebuffer", name)) {
        return @ptrCast(&myVkDestroyFramebuffer);
    } else if (std.mem.eql(u8, "vkDestroyImage", name)) {
        return @ptrCast(&myVkDestroyImage);
    } else if (std.mem.eql(u8, "vkDestroyImageView", name)) {
        return @ptrCast(&myVkDestroyImageView);
    } else if (std.mem.eql(u8, "vkDestroyPipeline", name)) {
        return @ptrCast(&myVkDestroyPipeline);
    } else if (std.mem.eql(u8, "vkDestroyPipelineLayout", name)) {
        return @ptrCast(&myVkDestroyPipelineLayout);
    } else if (std.mem.eql(u8, "vkDestroyRenderPass", name)) {
        return @ptrCast(&myVkDestroyRenderPass);
    } else if (std.mem.eql(u8, "vkDestroySampler", name)) {
        return @ptrCast(&myVkDestroySampler);
    } else if (std.mem.eql(u8, "vkDestroySemaphore", name)) {
        return @ptrCast(&myVkDestroySemaphore);
    } else if (std.mem.eql(u8, "vkDestroyShaderModule", name)) {
        return @ptrCast(&myVkDestroyShaderModule);
    } else if (std.mem.eql(u8, "vkDestroySurfaceKHR", name)) {
        return @ptrCast(&myVkDestroySurfaceKHR);
    } else if (std.mem.eql(u8, "vkDestroySwapchainKHR", name)) {
        return @ptrCast(&myVkDestroySwapchainKHR);
    } else if (std.mem.eql(u8, "vkDeviceWaitIdle", name)) {
        return @ptrCast(&myVkDeviceWaitIdle);
    } else if (std.mem.eql(u8, "vkEnumeratePhysicalDevices", name)) {
        return @ptrCast(&myVkEnumeratePhysicalDevices);
    } else if (std.mem.eql(u8, "vkEndCommandBuffer", name)) {
        return @ptrCast(&myVkEndCommandBuffer);
    } else if (std.mem.eql(u8, "vkFlushMappedMemoryRanges", name)) {
        return @ptrCast(&myVkFlushMappedMemoryRanges);
    } else if (std.mem.eql(u8, "vkFreeCommandBuffers", name)) {
        return @ptrCast(&myVkFreeCommandBuffers);
    } else if (std.mem.eql(u8, "vkFreeDescriptorSets", name)) {
        return @ptrCast(&myVkFreeDescriptorSets);
    } else if (std.mem.eql(u8, "vkFreeMemory", name)) {
        return @ptrCast(&myVkFreeMemory);
    } else if (std.mem.eql(u8, "vkGetBufferMemoryRequirements", name)) {
        return @ptrCast(&myVkGetBufferMemoryRequirements);
    } else if (std.mem.eql(u8, "vkGetDeviceQueue", name)) {
        return @ptrCast(&myVkGetDeviceQueue);
    } else if (std.mem.eql(u8, "vkGetImageMemoryRequirements", name)) {
        return @ptrCast(&myVkGetImageMemoryRequirements);
    } else if (std.mem.eql(u8, "vkGetPhysicalDeviceProperties", name)) {
        return @ptrCast(&myVkGetPhysicalDeviceProperties);
    } else if (std.mem.eql(u8, "vkGetPhysicalDeviceMemoryProperties", name)) {
        return @ptrCast(&myVkGetPhysicalDeviceMemoryProperties);
    } else if (std.mem.eql(u8, "vkGetPhysicalDeviceQueueFamilyProperties", name)) {
        return @ptrCast(&myVkGetPhysicalDeviceQueueFamilyProperties);
    } else if (std.mem.eql(u8, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR", name)) {
        return @ptrCast(&myVkGetPhysicalDeviceSurfaceCapabilitiesKHR);
    } else if (std.mem.eql(u8, "vkGetPhysicalDeviceSurfaceFormatsKHR", name)) {
        return @ptrCast(&myVkGetPhysicalDeviceSurfaceFormatsKHR);
    } else if (std.mem.eql(u8, "vkGetPhysicalDeviceSurfacePresentModesKHR", name)) {
        return @ptrCast(&myVkGetPhysicalDeviceSurfacePresentModesKHR);
    } else if (std.mem.eql(u8, "vkGetSwapchainImagesKHR", name)) {
        return @ptrCast(&myVkGetSwapchainImagesKHR);
    } else if (std.mem.eql(u8, "vkMapMemory", name)) {
        return @ptrCast(&myVkMapMemory);
    } else if (std.mem.eql(u8, "vkQueueSubmit", name)) {
        return @ptrCast(&myVkQueueSubmit);
    } else if (std.mem.eql(u8, "vkQueueWaitIdle", name)) {
        return @ptrCast(&myVkQueueWaitIdle);
    } else if (std.mem.eql(u8, "vkResetCommandPool", name)) {
        return @ptrCast(&myVkResetCommandPool);
    } else if (std.mem.eql(u8, "vkResetFences", name)) {
        return @ptrCast(&myVkResetFences);
    } else if (std.mem.eql(u8, "vkUnmapMemory", name)) {
        return @ptrCast(&myVkUnmapMemory);
    } else if (std.mem.eql(u8, "vkUpdateDescriptorSets", name)) {
        return @ptrCast(&myVkUpdateDescriptorSets);
    } else if (std.mem.eql(u8, "vkWaitForFences", name)) {
        return @ptrCast(&myVkWaitForFences);
    } else if (std.mem.eql(u8, "vkCmdBeginRendering", name)) {
        return @ptrCast(&myVkCmdBeginRendering);
    } else if (std.mem.eql(u8, "vkCmdEndRendering", name)) {
        return @ptrCast(&myVkCmdEndRendering);
    }

    return vkGetInstanceProcAddr(
        g_vk_ctx.instance.handle,
        p_name,
    );
}

fn myVkAllocateCommandBuffers(
    device: c.VkDevice,
    pAllocateInfo: [*c]const c.VkCommandBufferAllocateInfo,
    pCommandBuffers: [*c]c.VkCommandBuffer,
) callconv(.C) void {
    _ = device;

    g_vk_ctx.device.allocateCommandBuffers(
        @ptrCast(pAllocateInfo),
        @ptrCast(pCommandBuffers),
    ) catch return;
}

fn myVkAllocateDescriptorSets() callconv(.C) void {
    // c.vkAllocateDescriptorSets;
}

fn myVkAllocateMemory() callconv(.C) void {
    // c.vkAllocateMemory;
}

fn myVkBeginCommandBuffer() callconv(.C) void {
    // c.vkBeginCommandBuffer;
}

fn myVkBindBufferMemory() callconv(.C) void {
    // c.vkBindBufferMemory;
}

fn myVkBindImageMemory() callconv(.C) void {
    // c.vkBindImageMemor;
}

fn myVkCmdBindDescriptorSets() callconv(.C) void {
    // c.vkCmdBindDescriptorSets;
}

fn myVkCmdBindIndexBuffer() callconv(.C) void {
    // c.vkCmdBindIndexBuffer;
}

fn myVkCmdBindPipeline() callconv(.C) void {
    // c.vkCmdBindPipelin;
}

fn myVkCmdBindVertexBuffers() callconv(.C) void {
    // c.vkCmdBindVertexBuffers;
}

fn myVkCmdCopyBufferToImage() callconv(.C) void {
    // c.vkCmdCopyBufferToImage;
}

fn myVkCmdDrawIndexed() callconv(.C) void {
    // c.vkCmdDrawIndexed;
}

fn myVkCmdPipelineBarrier() callconv(.C) void {
    // c.vkCmdPipelineBarrier;
}

fn myVkCmdPushConstants() callconv(.C) void {
    // c.vkCmdPushConstants;
}

fn myVkCmdSetScissor() callconv(.C) void {
    // c.vkCmdSetScissor;
}

fn myVkCmdSetViewport() callconv(.C) void {
    // c.vkCmdSetViewport;
}

fn myVkCreateBuffer() callconv(.C) void {
    // c.vkCreateBuffer;
}

fn myVkCreateCommandPool() callconv(.C) void {
    // c.vkCreateCommandPool;
}

fn myVkCreateDescriptorPool() callconv(.C) void {
    // c.vkCreateDescriptorPool;
}

fn myVkCreateDescriptorSetLayout() callconv(.C) void {
    // c.vkCreateDescriptorSetLayout;
}

fn myVkCreateFence() callconv(.C) void {
    // c.vkCreateFenc;
}

fn myVkCreateFramebuffer() callconv(.C) void {
    // c.vkCreateFramebuffer;
}

fn myVkCreateGraphicsPipelines() callconv(.C) void {
    // c.vkCreateGraphicsPipeline;
}

fn myVkCreateImage() callconv(.C) void {
    // c.vkCreateImag;
}

fn myVkCreateImageView() callconv(.C) void {
    // c.vkCreateImageVie;
}

fn myVkCreatePipelineLayout() callconv(.C) void {
    // c.vkCreatePipelineLayout;
}

fn myVkCreateRenderPass() callconv(.C) void {
    // c.vkCreateRenderPass;
}

fn myVkCreateSampler() callconv(.C) void {
    // c.vkCreateSampler;
}

fn myVkCreateSemaphore() callconv(.C) void {
    // c.vkCreateSemaphor;
}

fn myVkCreateShaderModule() callconv(.C) void {
    // c.vkCreateShaderModule;
}

fn myVkCreateSwapchainKHR() callconv(.C) void {
    // c.vkCreateSwapchainKHR;
}

fn myVkDestroyBuffer() callconv(.C) void {
    // c.vkDestroyBuffer;
}

fn myVkDestroyCommandPool() callconv(.C) void {
    // c.vkDestroyCommandPool;
}

fn myVkDestroyDescriptorPool() callconv(.C) void {
    // c.vkDestroyDescriptorPool;
}

fn myVkDestroyDescriptorSetLayout() callconv(.C) void {
    // c.vkDestroyDescriptorSetLayout;
}

fn myVkDestroyFence() callconv(.C) void {
    // c.vkDestroyFence;
}

fn myVkDestroyFramebuffer() callconv(.C) void {
    // c.vkDestroyFramebuffer;
}

fn myVkDestroyImage() callconv(.C) void {
    // c.vkDestroyImage;
}

fn myVkDestroyImageView() callconv(.C) void {
    // c.vkDestroyImageView;
}

fn myVkDestroyPipeline() callconv(.C) void {
    // c.vkDestroyPipelin;
}

fn myVkDestroyPipelineLayout() callconv(.C) void {
    // c.vkDestroyPipelineLayout;
}

fn myVkDestroyRenderPass() callconv(.C) void {
    // c.vkDestroyRenderPass;
}

fn myVkDestroySampler() callconv(.C) void {
    // c.vkDestroySampler;
}

fn myVkDestroySemaphore() callconv(.C) void {
    // c.vkDestroySemaphore;
}

fn myVkDestroyShaderModule() callconv(.C) void {
    // c.vkDestroyShaderModul;
}

fn myVkDestroySurfaceKHR() callconv(.C) void {
    // c.vkDestroySurfaceKHR;
}

fn myVkDestroySwapchainKHR() callconv(.C) void {
    // c.vkDestroySwapchainKH;
}

fn myVkDeviceWaitIdle() callconv(.C) void {
    // c.vkDeviceWaitIdle;
}

fn myVkEnumeratePhysicalDevices() callconv(.C) void {
    // c.vkEnumeratePhysicalDevices;
}

fn myVkEndCommandBuffer() callconv(.C) void {
    // c.vkEndCommandBuffer;
}

fn myVkFlushMappedMemoryRanges() callconv(.C) void {
    // c.vkFlushMappedMemoryRange;
}

fn myVkFreeCommandBuffers() callconv(.C) void {
    // c.vkFreeCommandBuffers;
}

fn myVkFreeDescriptorSets() callconv(.C) void {
    // c.vkFreeDescriptorSets;
}

fn myVkFreeMemory() callconv(.C) void {
    // c.vkFreeMemory;
}

fn myVkGetBufferMemoryRequirements() callconv(.C) void {
    // c.vkGetBufferMemoryRequirement;
}

fn myVkGetDeviceQueue() callconv(.C) void {
    // c.vkGetDeviceQueue;
}

fn myVkGetImageMemoryRequirements() callconv(.C) void {
    // c.vkGetImageMemoryRequirements;
}

fn myVkGetPhysicalDeviceProperties(physicalDevice: c.VkPhysicalDevice, pProperties: [*c]c.VkPhysicalDeviceProperties) callconv(.C) void {
    _ = physicalDevice;

    pProperties.* = @bitCast(g_vk_ctx.instance.getPhysicalDeviceProperties(g_vk_ctx.physical_device));
}

fn myVkGetPhysicalDeviceMemoryProperties() callconv(.C) void {
    // c.vkGetPhysicalDeviceMemoryProperties;
}

fn myVkGetPhysicalDeviceQueueFamilyProperties() callconv(.C) void {
    // c.vkGetPhysicalDeviceQueueFamilyProperties;
}

fn myVkGetPhysicalDeviceSurfaceCapabilitiesKHR() callconv(.C) void {
    // c.vkGetPhysicalDeviceSurfaceCapabilitiesKH;
}

fn myVkGetPhysicalDeviceSurfaceFormatsKHR() callconv(.C) void {
    // c.vkGetPhysicalDeviceSurfaceFormatsKHR;
}

fn myVkGetPhysicalDeviceSurfacePresentModesKHR() callconv(.C) void {
    // c.vkGetPhysicalDeviceSurfacePresentModesKH;
}

fn myVkGetSwapchainImagesKHR() callconv(.C) void {
    // c.vkGetSwapchainImagesKHR;
}

fn myVkMapMemory() callconv(.C) void {
    // c.vkMapMemory;
}

fn myVkQueueSubmit() callconv(.C) void {
    // c.vkQueueSubmi;
}

fn myVkQueueWaitIdle() callconv(.C) void {
    // c.vkQueueWaitIdle;
}

fn myVkResetCommandPool() callconv(.C) void {
    // c.vkResetCommandPool;
}

fn myVkResetFences() callconv(.C) void {
    // c.vkResetFence;
}

fn myVkUnmapMemory() callconv(.C) void {
    // c.vkUnmapMemor;
}

fn myVkUpdateDescriptorSets() callconv(.C) void {
    // c.vkUpdateDescriptorSets;
}

fn myVkWaitForFences() callconv(.C) void {
    // c.vkWaitForFences;
}

fn myVkCmdBeginRendering() callconv(.C) void {
    // c.vkCmdBeginRendering;
}

fn myVkCmdEndRendering() callconv(.C) void {
    // c.vkCmdEndRenderin;
}

const std = @import("std");
const vk = @import("vulkan");
const sdl = @import("sdl3");

const VK_CTX = @import("./vk_ctx.zig").VK_CTX;

const renderer = @import("./renderer.zig");
const vk_init = @import("./vk_initializers.zig");

const c = @cImport({
    // @cInclude("SDL3/SDL.h");
    // @cInclude("SDL3/SDL_vulkan.h");
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", {});
    @cDefine("IMGUI_IMPL_VULKAN_USE_LOADER", {});
    @cDefine("IMGUI_IMPL_VULKAN_HAS_DYNAMIC_RENDERING", {});
    @cDefine("IMGUI_IMPL_VULKAN_NO_PROTOTYPES", {});
    // @cDefine("VK_NO_PROTOTYPES", {});
    @cInclude("dcimgui.h");
    @cInclude("backends/dcimgui_impl_sdl3.h");
    @cInclude("backends/dcimgui_impl_vulkan.h");
});
