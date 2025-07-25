//! A vulkan render engine

pub const Engine = struct {
    /// Memory allocator
    allocator: std.mem.Allocator,
    /// The current frame number
    frame_number: usize = 0,
    /// If the engine should be rendering now
    stop_rendering: bool = false,
    /// Size of the render window
    window_extent: vk.Extent2D,
    /// SDL init flags
    init_flags: sdl.InitFlags,
    /// The application window
    window: sdl.video.Window,

    /// Vulkan context
    renderer: Renderer,

    pub fn init(allocator: std.mem.Allocator) !Engine {
        var self: Engine = .{
            .allocator = allocator,
            .frame_number = 0,
            .stop_rendering = false,
            .window_extent = .{ .width = 1700, .height = 900 },
            .init_flags = .{ .video = true },
            .window = undefined,
            .renderer = undefined,
        };

        try sdl.init(self.init_flags);

        const window_flags: sdl.video.WindowFlags = .{ .vulkan = true };
        self.window = try sdl.video.Window.init(
            "Zig Vulkan Tutorial",
            @intCast(self.window_extent.width),
            @intCast(self.window_extent.height),
            window_flags,
        );

        self.renderer = try Renderer.init(self.allocator, self.window, self.window_extent);
        std.log.debug("[Engine][Renderer] Initialized successfully!", .{});

        std.log.debug("[Engine] Initialized successfully!", .{});

        return self;
    }

    pub fn deinit(self: *Engine) void {
        self.renderer.deinit();
        std.log.debug("[Engine][Renderer] Deinitialized successfully!", .{});

        self.window.deinit();
        sdl.quit(self.init_flags);
        sdl.shutdown();

        std.log.debug("[Engine] Deinitialized successfully!", .{});
    }

    pub fn run(self: *Engine) !void {
        game_loop: while (true) {
            while (sdl.events.poll()) |event| switch (event) {
                .key_down => |key_down| if (key_down.key) |key| {
                    if (key == .escape) break :game_loop;
                },
                .quit => break :game_loop,
                .terminating => break :game_loop,
                .window_resized => {
                    std.log.info("[Window] Resized", .{});
                },
                .window_minimized, .window_focus_lost => {
                    self.stop_rendering = true;
                    std.log.debug("[Rendering] Stopped.", .{});
                },
                .window_restored, .window_focus_gained => {
                    self.stop_rendering = false;
                    std.log.debug("[Rendering] Resumed.", .{});
                },
                else => {
                    // std.log.debug("else: {d}", .{e.type});
                },
            };

            if (self.stop_rendering) {
                std.time.sleep(std.time.ns_per_ms * 100);
                continue;
            }

            try self.draw();

            break :game_loop; // TODO: REMOVE once basic rendering works
        }
    }

    fn draw(self: *Engine) !void {
        _ = self;
    }
};

const std = @import("std");
const sdl = @import("sdl3");
const vk = @import("vulkan");

const Renderer = @import("./renderer/renderer.zig").Renderer;
