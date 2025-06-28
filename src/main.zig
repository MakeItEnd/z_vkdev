pub fn main() !void {
    std.debug.print("Welcome to the zig vulkan guide!\n", .{});

    var debug_alloc = std.heap.DebugAllocator(.{}){};
    defer _ = debug_alloc.deinit();

    var engine: Engine = try Engine.init(debug_alloc.allocator());
    defer engine.deinit();

    try engine.run();
}

const std = @import("std");

const lib = @import("z_vkdev_lib");
const Engine = lib.Engine;
