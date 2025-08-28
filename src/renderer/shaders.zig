//! Shader helper

pub fn load_module(
    vk_ctx: *const VK_CTX,
    file_path: []const u8,
) !vk.ShaderModule {
    const file = try std.fs.cwd().openFile(file_path, .{});
    const file_size = (try file.stat()).size;

    // Ensure file size is a multiple of 4
    if (file_size % 4 != 0) {
        return error.InvalidSpirvSize;
    }

    try file.seekTo(0);
    const buffer = try file.readToEndAlloc(
        vk_ctx.allocator,
        file_size,
    );
    defer vk_ctx.allocator.free(buffer);
    file.close();

    const info: vk.ShaderModuleCreateInfo = .{
        .code_size = file_size,
        .p_code = @ptrCast(@alignCast(buffer.ptr)),
    };

    return try vk_ctx.device.createShaderModule(&info, null);
}

const std = @import("std");
const vk = @import("vulkan");
const VK_CTX = @import("./vk_ctx.zig").VK_CTX;
