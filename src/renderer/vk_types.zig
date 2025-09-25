//! General usage types for vulkand data

pub const Vertex = struct {
    position: [3]f32,
    uv_x: f32,
    normal: [3]f32,
    uv_y: f32,
    color: [4]f32,
};

// Holds the resources needed for a mesh.
pub const GPUMeshBuffers = struct {
    index_buffer: AllocatedBuffer,
    vertex_buffer: AllocatedBuffer,
    vertex_buffer_address: vk.DeviceAddress,

    pub fn deinit(self: GPUMeshBuffers, vk_ctx: *VK_CTX) void {
        self.index_buffer.deinit(vk_ctx);
        self.vertex_buffer.deinit(vk_ctx);
    }
};

pub const GPUDrawPushConstants = struct {
    world_matrix: [4]@Vector(4, f32),
    vertex_buffer: vk.DeviceAddress,
};

const vk = @import("vulkan");
const zm = @import("zm");
const AllocatedBuffer = @import("allocated_buffer.zig").AllocatedBuffer;
const VK_CTX = @import("./vk_ctx.zig").VK_CTX;
