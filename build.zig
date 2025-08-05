const std = @import("std");

// TODO: Add shader compilation to script `glslc --target-env=vulkan1.4 -o gradient.comp.spv gradient.comp `
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("z_vkdev_lib", lib_mod);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "z_vkdev",
        .root_module = lib_mod,
    });

    const sdl3 = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
        .callbacks = false,
        .ext_image = true,
        .c_sdl_preferred_linkage = .dynamic,
        // .c_sdl_strip = optimize != .Debug,
        //.c_sdl_sanitize_c = .off,
        .c_sdl_lto = .none,
        //.c_sdl_emscripten_pthreads = false,
        //.c_sdl_install_build_config_h = false,
    });
    lib.root_module.addImport("sdl3", sdl3.module("sdl3"));

    // Vulkan -----------------------------------------------------------------
    // ------------------------------------------------------------------------
    // [INFO] Using `vk.xml` Commit: 19b765119a9ddef1034e95442f82f94235167f36 Version: 1.4.313
    const vulkan = b.dependency("vulkan", .{
        .registry = b.dependency("vulkan_headers", .{}).path("registry/vk.xml"),
    }).module("vulkan-zig");
    lib.root_module.addImport("vulkan", vulkan);

    // Vulkan Memory Allocator ------------------------------------------------
    // ------------------------------------------------------------------------
    const zig_vma_dep = b.dependency("zig_vma", .{
        .target = target,
        .optimize = optimize,
    });
    const zig_vma = zig_vma_dep.module("zig_vma");
    zig_vma.addImport("vulkan", vulkan);

    lib.root_module.addImport("zig_vma", zig_vma);

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "z_vkdev",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
