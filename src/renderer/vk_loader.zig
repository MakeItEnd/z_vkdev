pub const GeoSurface = struct {
    start_index: u32,
    count: u32,
};

pub const MeshAsset = struct {
    name: [20]u8,
    surface: std.array_list.Aligned(GeoSurface, null),
    buffers: GPUMeshBuffers,

    pub fn deinit(self: *MeshAsset, renderer: *Renderer) void {
        self.surface.deinit(renderer.allocator);
        self.buffers.deinit(renderer.vk_ctx);
    }
};

// std::optional<std::vector<std::shared_ptr<MeshAsset>>>
// loadGltfMeshes(VulkanEngine* engine, std::filesystem::path filePath);
pub fn load_gltf_meshes(
    renderer: *Renderer,
    file_path: []const u8,
) !?std.array_list.Aligned(MeshAsset, null) {
    std.log.debug("[Loader][GLTF] Loading {s}", .{file_path});

    const buffer = try std.fs.cwd().readFileAllocOptions(
        renderer.allocator,
        file_path,
        512_000,
        null,
        .@"4",
        null,
    );
    defer renderer.allocator.free(buffer);

    var gltf: Gltf = Gltf.init(renderer.allocator);
    try gltf.parse(buffer);
    defer gltf.deinit();

    var meshes: std.array_list.Aligned(MeshAsset, null) = try std.array_list.Aligned(MeshAsset, null).initCapacity(
        renderer.allocator,
        gltf.data.nodes.len,
    );
    // defer meshes.deinit(renderer.allocator);

    // use the same vectors for all meshes so that the memory doesnt reallocate as often
    var indices: std.array_list.Aligned(u32, null) = .empty;
    defer indices.deinit(renderer.allocator);
    var vertices: std.array_list.Aligned(Vertex, null) = .empty;
    defer vertices.deinit(renderer.allocator);
    for (gltf.data.meshes) |mesh| {
        var new_mesh: MeshAsset = undefined;
        new_mesh.name = @splat(' ');
        new_mesh.surface = .empty;
        // if (mesh.name) |n| {
        //     @memcpy(new_mesh.name, n);
        // } else {}

        indices.clearAndFree(renderer.allocator);
        vertices.clearAndFree(renderer.allocator);

        for (mesh.primitives) |primitive| {
            const new_surface: GeoSurface = .{
                .start_index = @intCast(indices.items.len),
                .count = @intCast(gltf.data.accessors[primitive.indices.?].count),
            };

            const initial_vtx: usize = vertices.items.len;

            for (mesh.primitives) |mesh_primitive| {
                // Load indexes.
                if (mesh_primitive.indices) |indices_idx| {
                    const accessor = gltf.data.accessors[indices_idx];

                    try indices.ensureTotalCapacity(
                        renderer.allocator,
                        indices.items.len + accessor.count,
                    );
                    var it = accessor.iterator(
                        u16,
                        &gltf,
                        gltf.glb_binary.?,
                    );
                    var i: usize = 0;
                    while (it.next()) |n| : (i += 1) {
                        indices.appendAssumeCapacity(@intCast(n[0]));
                        // indices.items[initial_vtx + i] = @intCast(n[0]);
                    }
                }

                for (mesh_primitive.attributes) |attribute| {
                    switch (attribute) {
                        .position => |idx| { // Load vertex positions.
                            const accessor = gltf.data.accessors[idx];
                            try vertices.ensureTotalCapacity(
                                renderer.allocator,
                                vertices.items.len + accessor.count,
                            );
                            var it = accessor.iterator(
                                f32,
                                &gltf,
                                gltf.glb_binary.?,
                            );
                            while (it.next()) |v| {
                                vertices.appendAssumeCapacity(.{
                                    .position = .{ v[0], v[1], v[2] },
                                    .normal = .{ 1.0, 0.0, 0.0 },
                                    .color = .{ 1.0, 1.0, 1.0, 1.0 },
                                    .uv_x = 0.0,
                                    .uv_y = 0.0,
                                });
                            }
                        },
                        .normal => |idx| { // Load vertex normals.
                            const accessor = gltf.data.accessors[idx];
                            var it = accessor.iterator(f32, &gltf, gltf.glb_binary.?);
                            var i: usize = 0;
                            while (it.next()) |n| : (i += 1) {
                                vertices.items[initial_vtx + i].normal = .{ n[0], n[1], n[2] };
                            }
                        },
                        .texcoord => |idx| { // Load UVs.
                            const accessor = gltf.data.accessors[idx];
                            var it = accessor.iterator(f32, &gltf, gltf.glb_binary.?);
                            var i: usize = 0;
                            while (it.next()) |n| : (i += 1) {
                                vertices.items[initial_vtx + i].uv_x = n[0];
                                vertices.items[initial_vtx + i].uv_y = n[1];
                            }
                        },
                        .color => |idx| { // Load colors.
                            const accessor = gltf.data.accessors[idx];
                            var it = accessor.iterator(f32, &gltf, gltf.glb_binary.?);
                            var i: usize = 0;
                            while (it.next()) |c| : (i += 1) {
                                vertices.items[initial_vtx + i].color = .{ c[0], c[1], c[2], c[3] };
                            }
                        },
                        else => {},
                    }
                }
            }

            try new_mesh.surface.append(renderer.allocator, new_surface);
        }

        // Display vertex normals.
        const OverrideColors: bool = true;
        if (OverrideColors) {
            for (vertices.items) |*vertex| {
                vertex.color = .{
                    vertex.normal[0],
                    vertex.normal[1],
                    vertex.normal[2],
                    1.0,
                };
            }
        }

        new_mesh.buffers = try renderer.upload_mesh(indices.items, vertices.items);

        try meshes.append(renderer.allocator, new_mesh);

        // Or use the debufPrint method.
        // gltf.debugPrint();
    }

    return meshes;
}

const std = @import("std");
const Gltf = @import("zgltf").Gltf;
const GPUMeshBuffers = @import("./vk_types.zig").GPUMeshBuffers;
const Renderer = @import("./renderer.zig").Renderer;
const Vertex = @import("./vk_types.zig").Vertex;
