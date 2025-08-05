pub const DescriptorLayoutBuilder = struct {
    bindings: std.ArrayList(vk.DescriptorSetLayoutBinding),

    pub fn init(allocator: std.mem.Allocator) DescriptorLayoutBuilder {
        return .{
            .bindings = std.ArrayList(vk.DescriptorSetLayoutBinding).init(allocator),
        };
    }

    pub fn deinit(self: *DescriptorLayoutBuilder) void {
        self.bindings.deinit();
    }

    pub fn add_binding(
        self: *DescriptorLayoutBuilder,
        binding: u32,
        binding_type: vk.DescriptorType,
    ) !void {
        try self.bindings.append(.{
            .binding = binding,
            .descriptor_type = binding_type,
            .descriptor_count = 1,
            .stage_flags = .{},
            .p_immutable_samplers = null,
        });
    }

    pub fn clear(self: *DescriptorLayoutBuilder) void {
        self.bindings.clearRetainingCapacity();
    }

    pub fn build(
        self: *DescriptorLayoutBuilder,
        vk_ctx: *VK_CTX,
        shader_stages: vk.ShaderStageFlags,
        p_next: ?*const anyopaque,
        flags: vk.DescriptorSetLayoutCreateFlags,
    ) !vk.DescriptorSetLayout {
        for (self.bindings.items) |*binding| {
            binding.stage_flags = binding.stage_flags.merge(shader_stages);
        }

        const info: vk.DescriptorSetLayoutCreateInfo = .{
            .p_next = p_next,
            .flags = flags,
            .binding_count = @intCast(self.bindings.items.len),
            .p_bindings = @ptrCast(self.bindings.items.ptr),
        };

        return try vk_ctx.device.createDescriptorSetLayout(&info, null);
    }
};

pub const DescriptorAllocator = struct {
    pub const PoolSizeRatio = struct {
        descriptor_type: vk.DescriptorType,
        ratio: f32,
    };

    pool: vk.DescriptorPool,

    pub fn init(
        vk_ctx: *VK_CTX,
        max_sets: u32,
        pool_rations: []const PoolSizeRatio,
    ) !DescriptorAllocator {
        var pool_sizes: std.ArrayList(vk.DescriptorPoolSize) = std.ArrayList(vk.DescriptorPoolSize).init(vk_ctx.allocator);
        defer pool_sizes.deinit();

        for (pool_rations) |ratio| {
            try pool_sizes.append(.{
                .type = ratio.descriptor_type,
                .descriptor_count = @intFromFloat(ratio.ratio * @as(f32, @floatFromInt(max_sets))),
            });
        }

        const info: vk.DescriptorPoolCreateInfo = .{
            .flags = .{},
            .max_sets = max_sets,
            .pool_size_count = @intCast(pool_sizes.items.len),
            .p_pool_sizes = @ptrCast(pool_sizes.items.ptr),
        };

        return .{
            .pool = try vk_ctx.device.createDescriptorPool(
                &info,
                null,
            ),
        };
    }

    pub fn deinit(
        self: DescriptorAllocator,
        vk_ctx: *VK_CTX,
    ) void {
        vk_ctx.device.destroyDescriptorPool(self.pool, null);
    }

    pub fn clear_descriptors(
        self: *DescriptorAllocator,
        vk_ctx: *VK_CTX,
    ) void {
        vk_ctx.device.resetDescriptorPool(self.pool, .{});
    }

    pub fn allocate(
        self: *DescriptorAllocator,
        vk_ctx: *VK_CTX,
        layout: vk.DescriptorSetLayout,
    ) !vk.DescriptorSet {
        const info: vk.DescriptorSetAllocateInfo = .{
            .descriptor_pool = self.pool,
            .descriptor_set_count = 1,
            .p_set_layouts = @ptrCast(&layout),
        };

        var ds: vk.DescriptorSet = .null_handle;
        try vk_ctx.device.allocateDescriptorSets(&info, @ptrCast(&ds));

        return ds;
    }
};

const std = @import("std");
const vk = @import("vulkan");

const VK_CTX = @import("./vk_ctx.zig").VK_CTX;
