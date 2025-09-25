pub const AllocatedBuffer = struct {
    handle: vk.Buffer,
    allocation: zig_vma.Allocation,
    info: zig_vma.AllocationInfo,

    pub fn init(
        vk_ctx: *VK_CTX,
        alloc_size: usize,
        usage: vk.BufferUsageFlags,
        memory_usage: zig_vma.c.MemoryUsage,
    ) !AllocatedBuffer {
        // Allocate buffer.
        const buffer_info: vk.BufferCreateInfo = .{
            .size = alloc_size,
            .usage = usage,
            .sharing_mode = .exclusive,
        };

        const vmaallocInfo: zig_vma.AllocationCreateInfo = .{
            .usage = memory_usage,
            .flags = .{ .mapped_bit = true },
        };
        var self: AllocatedBuffer = undefined;

        // Allocate the buffer.
        self.handle = try vk_ctx.vma.bufferCreate(&buffer_info, &vmaallocInfo, &self.allocation, &self.info);

        return self;
    }

    pub fn deinit(self: AllocatedBuffer, vk_ctx: *VK_CTX) void {
        vk_ctx.vma.bufferDestroy(self.handle, self.allocation);
    }
};

const std = @import("std");
const vk = @import("vulkan");
const zig_vma = @import("zig_vma");

const VK_CTX = @import("./vk_ctx.zig").VK_CTX;
