//! Vulkan bootstrap instance builder.

pub const InstanceBuilder = struct {
    allocator: std.mem.Allocator,
    vkb: *vk.BaseWrapper,
    enable_validation_layers: bool,
    debug_messenger: vk.PfnDebugUtilsMessengerCallbackEXT,
    application_name: ?[*:0]const u8,
    application_version: u32,
    engine_name: ?[*:0]const u8,
    engine_version: u32,
    api_version: u32,

    pub fn new(
        allocator: std.mem.Allocator,
        vkb: *vk.BaseWrapper,
        enable_validation: bool,
    ) InstanceBuilder {
        var self: InstanceBuilder = .{
            .allocator = allocator,
            .vkb = vkb,
            .enable_validation_layers = false,
            .debug_messenger = null,
            .application_name = "Zig Vulkan Guide",
            .application_version = @bitCast(vk.makeApiVersion(0, 0, 1, 0)),
            .engine_name = "Test Zig Vulkan Engine",
            .engine_version = @bitCast(vk.makeApiVersion(0, 0, 1, 0)),
            .api_version = @bitCast(vk.API_VERSION_1_4),
        };

        if (enable_validation) {
            self.enable_validation_layers = true;
            self.debug_messenger = debugCallback;
        }

        return self;
    }

    pub fn build(self: InstanceBuilder) !struct {
        instance_proxy: vk.InstanceProxy,
        debug_messenger: vk.DebugUtilsMessengerEXT,
    } {
        // Check extensions -------------------------------------------------------
        // ------------------------------------------------------------------------
        var extension_names = std.array_list.Aligned([*:0]const u8, null){};
        defer extension_names.deinit(self.allocator);
        // these extensions are to support vulkan in mac os
        // see https://github.com/glfw/glfw/issues/2335
        if (@import("builtin").os.tag == .macos) {
            try extension_names.append(self.allocator, vk.extensions.khr_portability_enumeration.name);
        }
        try extension_names.append(self.allocator, vk.extensions.khr_get_physical_device_properties_2.name);

        if (self.enable_validation_layers) {
            try extension_names.append(self.allocator, vk.extensions.ext_debug_utils.name);
        }

        const sdl_extensions = try sdl3.vulkan.getInstanceExtensions();
        // try extension_names.appendSlice(@ptrCast(sdl_extensions[0..sdl_extensions.len]));
        try extension_names.appendSlice(self.allocator, @ptrCast(sdl_extensions[0..sdl_extensions.len]));
        for (extension_names.items) |extension| {
            std.log.debug("Instance Enabled Extension: {s}", .{extension});
        }

        try checkInstanceExtensions(&self, extension_names.items);

        // Check Layer Support ----------------------------------------------------
        // ------------------------------------------------------------------------
        if (self.enable_validation_layers and !(try self.checkValidationLayerSupport())) {
            std.log.err("Instance Layer Property: 'VK_LAYER_KHRONOS_validation' is not available!", .{});

            return error.requiredInstanceLayerPropertyNotAvailable;
        }

        var create_info: vk.InstanceCreateInfo = .{
            .p_application_info = &.{
                .p_application_name = self.application_name,
                .application_version = self.application_version,
                .p_engine_name = self.engine_name,
                .engine_version = self.engine_version,
                .api_version = self.api_version,
            },
            .enabled_extension_count = @intCast(extension_names.items.len),
            .pp_enabled_extension_names = extension_names.items.ptr,
            // enumerate_portability_bit_khr to support vulkan in mac os
            // see https://github.com/glfw/glfw/issues/2335
            .flags = .{ .enumerate_portability_bit_khr = true },
        };
        var debug_create_info: vk.DebugUtilsMessengerCreateInfoEXT = undefined;

        const validation_layers: [1][*:0]const u8 = .{"VK_LAYER_KHRONOS_validation"};
        if (self.enable_validation_layers) {
            create_info.enabled_layer_count = @intCast(validation_layers.len);
            create_info.pp_enabled_layer_names = &validation_layers;

            debug_create_info = populateDebugUtilsMessengerCreateInfoEXT();
            create_info.p_next = @ptrCast(&debug_create_info);
        }

        const instance = try self.vkb.createInstance(&create_info, null);

        const vki = try self.allocator.create(vk.InstanceWrapper);
        errdefer self.allocator.destroy(vki);
        vki.* = vk.InstanceWrapper.load(
            instance,
            self.vkb.dispatch.vkGetInstanceProcAddr.?,
        );
        const instance_proxy: vk.InstanceProxy = vk.InstanceProxy.init(instance, vki);

        var debug_messenger: vk.DebugUtilsMessengerEXT = .null_handle;
        if (self.enable_validation_layers) {
            const create_Info: vk.DebugUtilsMessengerCreateInfoEXT = populateDebugUtilsMessengerCreateInfoEXT();
            debug_messenger = try instance_proxy.createDebugUtilsMessengerEXT(&create_Info, null);
        }

        return .{
            .instance_proxy = instance_proxy,
            .debug_messenger = debug_messenger,
        };
    }

    fn checkInstanceExtensions(
        self: *const InstanceBuilder,
        required_extensions: [][*:0]const u8,
    ) !void {
        const available_extensions = try self.vkb.enumerateInstanceExtensionPropertiesAlloc(null, self.allocator);
        defer self.allocator.free(available_extensions);

        // for (available_extensions) |ae| {
        //     std.log.debug("Av Ex: {s}", .{ae.extension_name});
        // }

        for (required_extensions) |required_extension| {
            var extension_exists: bool = false;
            for (available_extensions) |available_extension| {
                const extension_slice: []const u8 = std.mem.span(required_extension);

                // * available_extension have a len of 256 so comparison fails; to fix this we limit the len to the required required_extension len we search for.
                if (std.mem.eql(u8, extension_slice, available_extension.extension_name[0..extension_slice.len])) {
                    extension_exists = true;
                    break;
                }
            }

            if (!extension_exists) {
                std.log.err("Instance Extension: '{s}' is not available!", .{required_extension});

                return error.requiredInstanceExtensionNotAvailable;
            }

            std.log.debug("Instance Enabled Extension: {s}", .{required_extension});
        }
    }

    fn checkValidationLayerSupport(self: *const InstanceBuilder) !bool {
        const available_layer_properties = try self.vkb.enumerateInstanceLayerPropertiesAlloc(self.allocator);
        defer self.allocator.free(available_layer_properties);

        var layer_property_exists: bool = false;
        for (available_layer_properties) |layer_propertie| {
            // * available_layer_propertie has a len of 256 so comparison fails; to fix this we limit the len to the required required_extension len we search for.
            if (std.mem.eql(u8, "VK_LAYER_KHRONOS_validation", layer_propertie.layer_name[0..27])) {
                layer_property_exists = true;
                break;
            }
        }

        return layer_property_exists;
    }

    fn populateDebugUtilsMessengerCreateInfoEXT() vk.DebugUtilsMessengerCreateInfoEXT {
        return .{
            .message_severity = .{
                .verbose_bit_ext = true,
                .warning_bit_ext = true,
                .error_bit_ext = true,
            },
            .message_type = .{
                .general_bit_ext = true,
                .validation_bit_ext = true,
                .performance_bit_ext = true,
            },
            .pfn_user_callback = InstanceBuilder.debugCallback,
        };
    }

    /// vk.PfnDebugUtilsMessengerCallbackEXT;
    fn debugCallback(
        message_severity: vk.DebugUtilsMessageSeverityFlagsEXT,
        message_types: vk.DebugUtilsMessageTypeFlagsEXT,
        p_callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT,
        p_user_data: ?*anyopaque,
    ) callconv(vk.vulkan_call_conv) vk.Bool32 {
        _ = message_types;
        _ = p_user_data;

        if (message_severity.error_bit_ext) {
            std.log.err("{?s}", .{p_callback_data.?.p_message});
        } else if (message_severity.warning_bit_ext) {
            std.log.warn("{?s}", .{p_callback_data.?.p_message});
        } else if (message_severity.info_bit_ext) {
            std.log.info("{?s}", .{p_callback_data.?.p_message});
        } else if (message_severity.verbose_bit_ext) {
            std.log.info("{?s}", .{p_callback_data.?.p_message});
        }

        return vk.FALSE;
    }
};

const std = @import("std");
const sdl3 = @import("sdl3");
const vk = @import("vulkan");
