pub const AllocatedImage = struct {
    handle: vk.Image,
    view: vk.ImageView,
    allocation: zig_vma.Allocation,
    extent: vk.Extent3D,
    format: vk.Format,

    pub fn init(vk_ctx: *VK_CTX, window_extent: vk.Extent2D) !AllocatedImage {
        var self: AllocatedImage = undefined;

        // Hardcoding the draw format to 32 bit float.
        self.format = vk.Format.r16g16b16a16_sfloat;
        // Draw image size will match the window.
        self.extent = .{
            .width = window_extent.width,
            .height = window_extent.height,
            .depth = 1,
        };

        const create_info = vk_init.image_create_info(
            self.format,
            .{
                .transfer_src_bit = true,
                .transfer_dst_bit = true,
                .storage_bit = true,
                .color_attachment_bit = true,
            },
            self.extent,
        );

        // For the draw image, we want to allocate it from gpu local memory.
        self.handle = try vk_ctx.vma.imageCreate(
            &create_info,
            &.{
                .usage = .gpu_only,
                .required_flags = .{
                    .device_local_bit = true,
                },
            },
            &self.allocation,
            null,
        );

        // Build a image-view for the draw image to use for rendering.
        const view_create_info = vk_init.imageview_create_info(
            self.format,
            self.handle,
            .{
                .color_bit = true,
            },
        );

        self.view = try vk_ctx.device.createImageView(
            &view_create_info,
            null,
        );

        return self;
    }

    pub fn deinit(self: AllocatedImage, vk_ctx: *VK_CTX) void {
        vk_ctx.vma.imageDestroy(self.handle, self.allocation);
        vk_ctx.device.destroyImageView(self.view, null);
    }

    pub fn transition(
        self: *AllocatedImage,
        vk_ctx: *VK_CTX,
        cmd: vk.CommandBuffer,
        current_layout: vk.ImageLayout,
        new_layout: vk.ImageLayout,
    ) void {
        img_utils.transition(
            self.handle,
            vk_ctx,
            cmd,
            current_layout,
            new_layout,
        );
    }
};

const vk = @import("vulkan");
const zig_vma = @import("zig_vma");

const VK_CTX = @import("./vk_ctx.zig").VK_CTX;
const vk_init = @import("vk_initializers.zig");
const img_utils = @import("./image_utils.zig");
