const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");

pub const vulkan_call_conv: std.builtin.CallingConvention = if (builtin.os.tag == .windows and builtin.cpu.arch == .x86)
    .Stdcall
else if (builtin.abi == .android and (builtin.cpu.arch.isARM() or builtin.cpu.arch.isThumb()) and std.Target.arm.featureSetHas(builtin.cpu.features, .has_v7) and builtin.cpu.arch.ptrBitWidth() == 32)
    // On Android 32-bit ARM targets, Vulkan functions use the "hardfloat"
    // calling convention, i.e. float parameters are passed in registers. This
    // is true even if the rest of the application passes floats on the stack,
    // as it does by default when compiling for the armeabi-v7a NDK ABI.
    .AAPCSVFP
else
    .C;
pub fn FlagsMixin(comptime FlagsType: type) type {
    return struct {
        pub const IntType = @typeInfo(FlagsType).@"struct".backing_integer.?;
        pub fn toInt(self: FlagsType) IntType {
            return @bitCast(self);
        }
        pub fn fromInt(flags: IntType) FlagsType {
            return @bitCast(flags);
        }
        pub fn merge(lhs: FlagsType, rhs: FlagsType) FlagsType {
            return fromInt(toInt(lhs) | toInt(rhs));
        }
        pub fn intersect(lhs: FlagsType, rhs: FlagsType) FlagsType {
            return fromInt(toInt(lhs) & toInt(rhs));
        }
        pub fn complement(self: FlagsType) FlagsType {
            return fromInt(~toInt(self));
        }
        pub fn subtract(lhs: FlagsType, rhs: FlagsType) FlagsType {
            return fromInt(toInt(lhs) & toInt(rhs.complement()));
        }
        pub fn contains(lhs: FlagsType, rhs: FlagsType) bool {
            return toInt(intersect(lhs, rhs)) == toInt(rhs);
        }
    };
}
fn FlagFormatMixin(comptime FlagsType: type) type {
    return struct {
        pub fn format(
            self: FlagsType,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.writeAll(@typeName(FlagsType) ++ "{");
            var first = true;
            @setEvalBranchQuota(100_000);
            inline for (comptime std.meta.fieldNames(FlagsType)) |name| {
                if (name[0] == '_') continue;
                if (@field(self, name)) {
                    if (first) {
                        try writer.writeAll(" ." ++ name);
                        first = false;
                    } else {
                        try writer.writeAll(", ." ++ name);
                    }
                }
            }
            if (!first) try writer.writeAll(" ");
            try writer.writeAll("}");
        }
    };
}
pub const Flags = u32;

pub const AllocatorCreateFlags = packed struct(Flags) {
    externaly_synchronized_bit: bool = false,
    dedicated_allocation_bit_khr: bool = false,
    bind_memory2_bit_khr: bool = false,
    memory_budget_bit_ext: bool = false,
    device_coherent_memory_bit_amd: bool = false,
    buffer_device_address_bit: bool = false,
    memory_priority_bit_ext: bool = false,
    maintenance4_khr: bool = false,
    maintenance5_khr: bool = false,
    external_memory_win32_bit_khr: bool = false,
    _reserved_bit_10: bool = false,
    _reserved_bit_11: bool = false,
    _reserved_bit_12: bool = false,
    _reserved_bit_13: bool = false,
    _reserved_bit_14: bool = false,
    _reserved_bit_15: bool = false,
    _reserved_bit_16: bool = false,
    _reserved_bit_17: bool = false,
    _reserved_bit_18: bool = false,
    _reserved_bit_19: bool = false,
    _reserved_bit_20: bool = false,
    _reserved_bit_21: bool = false,
    _reserved_bit_22: bool = false,
    _reserved_bit_23: bool = false,
    _reserved_bit_24: bool = false,
    _reserved_bit_25: bool = false,
    _reserved_bit_26: bool = false,
    _reserved_bit_27: bool = false,
    _reserved_bit_28: bool = false,
    _reserved_bit_29: bool = false,
    _reserved_bit_30: bool = false,
    _reserved_bit_31: bool = false,
    pub const toInt = FlagsMixin(AllocatorCreateFlags).toInt;
    pub const fromInt = FlagsMixin(AllocatorCreateFlags).fromInt;
    pub const merge = FlagsMixin(AllocatorCreateFlags).merge;
    pub const intersect = FlagsMixin(AllocatorCreateFlags).intersect;
    pub const complement = FlagsMixin(AllocatorCreateFlags).complement;
    pub const subtract = FlagsMixin(AllocatorCreateFlags).subtract;
    pub const contains = FlagsMixin(AllocatorCreateFlags).contains;
    pub const format = FlagFormatMixin(AllocatorCreateFlags).format;
};

pub const MemoryUsage = enum(i32) {
    unknown = 0,
    gpu_only = 1,
    cpu_only = 2,
    cpu_to_gpu = 3,
    gpu_to_cpu = 4,
    cpu_copy = 5,
    gpu_lazily_allocated = 6,
    auto = 7,
    auto_prefer_device = 8,
    auto_prefer_host = 9,
    _,
};

pub const AllocationCreateFlags = packed struct(Flags) {
    dedicated_memory_bit: bool = false,
    never_allocate_bit: bool = false,
    mapped_bit: bool = false,
    _reserved_bit_3: bool = false,
    _reserved_bit_4: bool = false,
    user_data_copy_string_bit: bool = false,
    upper_address_bit: bool = false,
    dont_bind_bit: bool = false,
    within_budget_bit: bool = false,
    can_alias_bit: bool = false,
    host_access_sequential_write_bit: bool = false,
    host_access_random_bit: bool = false,
    host_access_allow_transfer_instead_bit: bool = false,
    _reserved_bit_13: bool = false,
    _reserved_bit_14: bool = false,
    _reserved_bit_15: bool = false,
    strategy_min_memory_bit: bool = false,
    strategy_min_time_bit: bool = false,
    strategy_min_offset_bit: bool = false,
    _reserved_bit_19: bool = false,
    _reserved_bit_20: bool = false,
    _reserved_bit_21: bool = false,
    _reserved_bit_22: bool = false,
    _reserved_bit_23: bool = false,
    _reserved_bit_24: bool = false,
    _reserved_bit_25: bool = false,
    _reserved_bit_26: bool = false,
    _reserved_bit_27: bool = false,
    _reserved_bit_28: bool = false,
    _reserved_bit_29: bool = false,
    _reserved_bit_30: bool = false,
    _reserved_bit_31: bool = false,
    pub const toInt = FlagsMixin(AllocationCreateFlags).toInt;
    pub const fromInt = FlagsMixin(AllocationCreateFlags).fromInt;
    pub const merge = FlagsMixin(AllocationCreateFlags).merge;
    pub const intersect = FlagsMixin(AllocationCreateFlags).intersect;
    pub const complement = FlagsMixin(AllocationCreateFlags).complement;
    pub const subtract = FlagsMixin(AllocationCreateFlags).subtract;
    pub const contains = FlagsMixin(AllocationCreateFlags).contains;
    pub const format = FlagFormatMixin(AllocationCreateFlags).format;
};

pub const PoolCreateFlags = packed struct(Flags) {
    _reserved_bit_0: bool = false,
    ignore_buffer_image_granularity_bit: bool = false,
    linear_algorithm_bit: bool = false,
    _reserved_bit_3: bool = false,
    _reserved_bit_4: bool = false,
    _reserved_bit_5: bool = false,
    _reserved_bit_6: bool = false,
    _reserved_bit_7: bool = false,
    _reserved_bit_8: bool = false,
    _reserved_bit_9: bool = false,
    _reserved_bit_10: bool = false,
    _reserved_bit_11: bool = false,
    _reserved_bit_12: bool = false,
    _reserved_bit_13: bool = false,
    _reserved_bit_14: bool = false,
    _reserved_bit_15: bool = false,
    _reserved_bit_16: bool = false,
    _reserved_bit_17: bool = false,
    _reserved_bit_18: bool = false,
    _reserved_bit_19: bool = false,
    _reserved_bit_20: bool = false,
    _reserved_bit_21: bool = false,
    _reserved_bit_22: bool = false,
    _reserved_bit_23: bool = false,
    _reserved_bit_24: bool = false,
    _reserved_bit_25: bool = false,
    _reserved_bit_26: bool = false,
    _reserved_bit_27: bool = false,
    _reserved_bit_28: bool = false,
    _reserved_bit_29: bool = false,
    _reserved_bit_30: bool = false,
    _reserved_bit_31: bool = false,
    pub const toInt = FlagsMixin(PoolCreateFlags).toInt;
    pub const fromInt = FlagsMixin(PoolCreateFlags).fromInt;
    pub const merge = FlagsMixin(PoolCreateFlags).merge;
    pub const intersect = FlagsMixin(PoolCreateFlags).intersect;
    pub const complement = FlagsMixin(PoolCreateFlags).complement;
    pub const subtract = FlagsMixin(PoolCreateFlags).subtract;
    pub const contains = FlagsMixin(PoolCreateFlags).contains;
    pub const format = FlagFormatMixin(PoolCreateFlags).format;
};

pub const DefragmentationFlags = packed struct(Flags) {
    _reserved_bit_0: bool = false,
    _reserved_bit_1: bool = false,
    _reserved_bit_2: bool = false,
    _reserved_bit_3: bool = false,
    _reserved_bit_4: bool = false,
    _reserved_bit_5: bool = false,
    _reserved_bit_6: bool = false,
    _reserved_bit_7: bool = false,
    _reserved_bit_8: bool = false,
    _reserved_bit_9: bool = false,
    _reserved_bit_10: bool = false,
    _reserved_bit_11: bool = false,
    _reserved_bit_12: bool = false,
    _reserved_bit_13: bool = false,
    _reserved_bit_14: bool = false,
    _reserved_bit_15: bool = false,
    _reserved_bit_16: bool = false,
    _reserved_bit_17: bool = false,
    _reserved_bit_18: bool = false,
    _reserved_bit_19: bool = false,
    _reserved_bit_20: bool = false,
    _reserved_bit_21: bool = false,
    _reserved_bit_22: bool = false,
    _reserved_bit_23: bool = false,
    _reserved_bit_24: bool = false,
    _reserved_bit_25: bool = false,
    _reserved_bit_26: bool = false,
    _reserved_bit_27: bool = false,
    algorithm_fast_bit: bool = false,
    algorithm_balanced_bit: bool = false,
    algorithm_full_bit: bool = false,
    algorithm_extensive_bit: bool = false,
    pub const toInt = FlagsMixin(DefragmentationFlags).toInt;
    pub const fromInt = FlagsMixin(DefragmentationFlags).fromInt;
    pub const merge = FlagsMixin(DefragmentationFlags).merge;
    pub const intersect = FlagsMixin(DefragmentationFlags).intersect;
    pub const complement = FlagsMixin(DefragmentationFlags).complement;
    pub const subtract = FlagsMixin(DefragmentationFlags).subtract;
    pub const contains = FlagsMixin(DefragmentationFlags).contains;
    pub const format = FlagFormatMixin(DefragmentationFlags).format;
};

pub const DefragmentationMoveOperation = enum(i32) {
    copy = 0,
    ignore = 1,
    destroy = 2,
    _,
};

pub const VirtualBlockCreateFlags = packed struct(Flags) {
    linear_algorithm_bit: bool = false,
    _reserved_bit_1: bool = false,
    _reserved_bit_2: bool = false,
    _reserved_bit_3: bool = false,
    _reserved_bit_4: bool = false,
    _reserved_bit_5: bool = false,
    _reserved_bit_6: bool = false,
    _reserved_bit_7: bool = false,
    _reserved_bit_8: bool = false,
    _reserved_bit_9: bool = false,
    _reserved_bit_10: bool = false,
    _reserved_bit_11: bool = false,
    _reserved_bit_12: bool = false,
    _reserved_bit_13: bool = false,
    _reserved_bit_14: bool = false,
    _reserved_bit_15: bool = false,
    _reserved_bit_16: bool = false,
    _reserved_bit_17: bool = false,
    _reserved_bit_18: bool = false,
    _reserved_bit_19: bool = false,
    _reserved_bit_20: bool = false,
    _reserved_bit_21: bool = false,
    _reserved_bit_22: bool = false,
    _reserved_bit_23: bool = false,
    _reserved_bit_24: bool = false,
    _reserved_bit_25: bool = false,
    _reserved_bit_26: bool = false,
    _reserved_bit_27: bool = false,
    _reserved_bit_28: bool = false,
    _reserved_bit_29: bool = false,
    _reserved_bit_30: bool = false,
    _reserved_bit_31: bool = false,
    pub const toInt = FlagsMixin(VirtualBlockCreateFlags).toInt;
    pub const fromInt = FlagsMixin(VirtualBlockCreateFlags).fromInt;
    pub const merge = FlagsMixin(VirtualBlockCreateFlags).merge;
    pub const intersect = FlagsMixin(VirtualBlockCreateFlags).intersect;
    pub const complement = FlagsMixin(VirtualBlockCreateFlags).complement;
    pub const subtract = FlagsMixin(VirtualBlockCreateFlags).subtract;
    pub const contains = FlagsMixin(VirtualBlockCreateFlags).contains;
    pub const format = FlagFormatMixin(VirtualBlockCreateFlags).format;
};

pub const VirtualAllocationCreateFlags = packed struct(Flags) {
    _reserved_bit_0: bool = false,
    _reserved_bit_1: bool = false,
    _reserved_bit_2: bool = false,
    _reserved_bit_3: bool = false,
    _reserved_bit_4: bool = false,
    _reserved_bit_5: bool = false,
    upper_address_bit: bool = false,
    _reserved_bit_7: bool = false,
    _reserved_bit_8: bool = false,
    _reserved_bit_9: bool = false,
    _reserved_bit_10: bool = false,
    _reserved_bit_11: bool = false,
    _reserved_bit_12: bool = false,
    _reserved_bit_13: bool = false,
    _reserved_bit_14: bool = false,
    _reserved_bit_15: bool = false,
    strategy_min_memory_bit: bool = false,
    strategy_min_time_bit: bool = false,
    strategy_min_offset_bit: bool = false,
    _reserved_bit_19: bool = false,
    _reserved_bit_20: bool = false,
    _reserved_bit_21: bool = false,
    _reserved_bit_22: bool = false,
    _reserved_bit_23: bool = false,
    _reserved_bit_24: bool = false,
    _reserved_bit_25: bool = false,
    _reserved_bit_26: bool = false,
    _reserved_bit_27: bool = false,
    _reserved_bit_28: bool = false,
    _reserved_bit_29: bool = false,
    _reserved_bit_30: bool = false,
    _reserved_bit_31: bool = false,
    pub const toInt = FlagsMixin(VirtualAllocationCreateFlags).toInt;
    pub const fromInt = FlagsMixin(VirtualAllocationCreateFlags).fromInt;
    pub const merge = FlagsMixin(VirtualAllocationCreateFlags).merge;
    pub const intersect = FlagsMixin(VirtualAllocationCreateFlags).intersect;
    pub const complement = FlagsMixin(VirtualAllocationCreateFlags).complement;
    pub const subtract = FlagsMixin(VirtualAllocationCreateFlags).subtract;
    pub const contains = FlagsMixin(VirtualAllocationCreateFlags).contains;
    pub const format = FlagFormatMixin(VirtualAllocationCreateFlags).format;
};

pub const Allocator = enum(usize) { null_handle = 0, _ };
pub const Pool = enum(usize) { null_handle = 0, _ };
pub const Allocation = enum(usize) { null_handle = 0, _ };
pub const DefragmentationContext = enum(usize) { null_handle = 0, _ };
pub const VirtualAllocation = enum(u64) { null_handle = 0, _ };
pub const VirtualBlock = enum(usize) { null_handle = 0, _ };

pub const PfnVmaAllocateDeviceMemoryFunction = ?*const fn (
    allocator: Allocator,
    memory_type: u32,
    memory: vk.DeviceMemory,
    size: vk.DeviceSize,
    p_user_data: ?*anyopaque,
) callconv(vulkan_call_conv) void;

pub const PfnVmaFreeDeviceMemoryFunction = ?*const fn (
    allocator: Allocator,
    memory_type: u32,
    memory: vk.DeviceMemory,
    size: vk.DeviceSize,
    p_user_data: ?*anyopaque,
) callconv(vulkan_call_conv) void;

pub const DeviceMemoryCallbacks = extern struct {
    pfn_allocate: PfnVmaAllocateDeviceMemoryFunction = null,
    pfn_free: PfnVmaFreeDeviceMemoryFunction = null,
    p_user_data: ?*anyopaque,
};

pub const VulkanFunctions = extern struct {
    vkGetInstanceProcAddr: vk.PfnGetInstanceProcAddr,
    vkGetDeviceProcAddr: vk.PfnGetDeviceProcAddr,
    vkGetPhysicalDeviceProperties: ?vk.PfnGetPhysicalDeviceProperties = null,
    vkGetPhysicalDeviceMemoryProperties: ?vk.PfnGetPhysicalDeviceMemoryProperties = null,
    vkAllocateMemory: ?vk.PfnAllocateMemory = null,
    vkFreeMemory: ?vk.PfnFreeMemory = null,
    vkMapMemory: ?vk.PfnMapMemory = null,
    vkUnmapMemory: ?vk.PfnUnmapMemory = null,
    vkFlushMappedMemoryRanges: ?vk.PfnFlushMappedMemoryRanges = null,
    vkInvalidateMappedMemoryRanges: ?vk.PfnInvalidateMappedMemoryRanges = null,
    vkBindBufferMemory: ?vk.PfnBindBufferMemory = null,
    vkBindImageMemory: ?vk.PfnBindImageMemory = null,
    vkGetBufferMemoryRequirements: ?vk.PfnGetBufferMemoryRequirements = null,
    vkGetImageMemoryRequirements: ?vk.PfnGetImageMemoryRequirements = null,
    vkCreateBuffer: ?vk.PfnCreateBuffer = null,
    vkDestroyBuffer: ?vk.PfnDestroyBuffer = null,
    vkCreateImage: ?vk.PfnCreateImage = null,
    vkDestroyImage: ?vk.PfnDestroyImage = null,
    vkCmdCopyBuffer: ?vk.PfnCmdCopyBuffer = null,
    vkGetBufferMemoryRequirements2KHR: ?vk.PfnGetBufferMemoryRequirements2KHR = null,
    vkGetImageMemoryRequirements2KHR: ?vk.PfnGetImageMemoryRequirements2KHR = null,
    vkBindBufferMemory2KHR: ?vk.PfnBindBufferMemory2KHR = null,
    vkBindImageMemory2KHR: ?vk.PfnBindImageMemory2KHR = null,
    vkGetPhysicalDeviceMemoryProperties2KHR: ?vk.PfnGetPhysicalDeviceMemoryProperties2KHR = null,
    vkGetDeviceBufferMemoryRequirements: ?vk.PfnGetDeviceBufferMemoryRequirements = null,
    vkGetDeviceImageMemoryRequirements: ?vk.PfnGetDeviceImageMemoryRequirements = null,
    vkGetMemoryWin32HandleKHR: ?vk.PfnGetMemoryWin32HandleKHR = null,
};

pub const AllocatorCreateInfo = extern struct {
    flags: AllocationCreateFlags = .{},
    physical_device: vk.PhysicalDevice,
    device: vk.Device,
    preferred_large_heap_block_size: vk.DeviceSize = 0,
    p_allocation_callbacks: ?[*]const vk.AllocationCallbacks = null,
    p_device_memory_callbacks: ?[*]const DeviceMemoryCallbacks = null,
    p_heap_size_limit: ?[*]const vk.DeviceSize = null,
    p_vulkan_functions: [*]const VulkanFunctions,
    instance: vk.Instance,
    vulkan_api_version: u32,
    p_type_external_memory_handle_types: ?[*]vk.ExternalMemoryHandleTypeFlagsKHR = null,
};

pub const AllocatorInfo = extern struct {
    instance: vk.Instance,
    physical_device: vk.PhysicalDevice,
    device: vk.Device,
};

pub const Statistics = extern struct {
    block_count: u32,
    allocation_count: u32,
    block_bytes: vk.DeviceSize,
    allocation_bytes: vk.DeviceSize,
};

pub const DetailedStatistics = extern struct {
    statistics: Statistics,
    unused_range_count: u32,
    allocation_size_min: vk.DeviceSize,
    allocation_size_max: vk.DeviceSize,
    unused_range_size_min: vk.DeviceSize,
    unused_range_size_max: vk.DeviceSize,
};

pub const TotalStatistics = extern struct {
    memory_type: [vk.MAX_MEMORY_TYPES]DetailedStatistics,
    memory_heap: [vk.MAX_MEMORY_HEAPS]DetailedStatistics,
    total: DetailedStatistics,
};

pub const Budget = extern struct {
    statistics: Statistics,
    usage: vk.DeviceSize,
    budget: vk.DeviceSize,
};

pub const AllocationCreateInfo = extern struct {
    flags: AllocationCreateFlags = .{},
    usage: MemoryUsage,
    required_flags: vk.MemoryPropertyFlags = .{},
    preferred_flags: vk.MemoryPropertyFlags = .{},
    memory_type_bits: u32 = 0,
    pool: ?Pool = null,
    p_user_data: ?*anyopaque = null,
    priority: f32 = 0.0,
};

pub const PoolCreateInfo = extern struct {
    memory_type_index: u32,
    flags: PoolCreateFlags = .{},
    block_size: vk.DeviceSize = 0,
    min_block_count: usize = 0,
    max_block_count: usize = 0,
    priority: f32 = 0.0,
    min_allocation_alignment: vk.DeviceSize = 0,
    p_memory_allocate_next: ?*anyopaque = null,
};

pub const AllocationInfo = extern struct {
    memory_type: u32,
    device_memory: vk.DeviceMemory,
    offset: vk.DeviceSize,
    size: vk.DeviceSize,
    p_mapped_data: ?*anyopaque = null,
    p_user_data: ?*anyopaque = null,
    p_name: ?[*:0]const u8 = null,
};

pub const AllocationInfo2 = extern struct {
    allocation_info: AllocationInfo,
    block_size: vk.DeviceSize,
    dedicated_memory: vk.Bool32,
};

pub const PfnVmaCheckDefragmentationBreakFunction = ?*const fn (
    p_user_data: ?*anyopaque,
) callconv(vulkan_call_conv) vk.Bool32;

pub const DefragmentationInfo = extern struct {
    flags: DefragmentationFlags = .{},
    pool: ?Pool = null,
    max_bytes_per_pass: vk.DeviceSize = 0,
    max_allocations_per_pass: u32 = 0,
    pfn_break_callback: ?PfnVmaCheckDefragmentationBreakFunction = null,
    p_break_callback_user_data: ?*anyopaque = null,
};

pub const DefragmentationMove = extern struct {
    operation: DefragmentationMoveOperation = .copy,
    src_allocation: Allocation,
    dst_tmp_allocation: Allocation,
};

pub const DefragmentationPassMoveInfo = extern struct {
    move_count: u32,
    p_moves: ?[*]DefragmentationMove = null,
};

pub const DefragmentationStats = extern struct {
    bytes_moved: vk.DeviceSize,
    bytes_freed: vk.DeviceSize,
    allocations_moved: u32,
    device_memory_blocks_freed: u32,
};

pub const VirtualBlockCreateInfo = extern struct {
    size: vk.DeviceSize,
    flags: VirtualBlockCreateFlags = .{},
    p_allocation_callbacks: ?[*]vk.AllocationCallbacks = null,
};

pub const VirtualAllocationCreateInfo = extern struct {
    size: vk.DeviceSize,
    alignment: vk.DeviceSize,
    flags: VirtualAllocationCreateFlags = .{},
    p_user_data: ?*anyopaque = null,
};

pub const VirtualAllocationInfo = extern struct {
    offset: vk.DeviceSize,
    size: vk.DeviceSize,
    p_user_data: ?*anyopaque = null,
};

pub extern fn vmaCreateAllocator(
    p_create_info: *const AllocatorCreateInfo,
    p_allocator: *Allocator,
) vk.Result;
pub extern fn vmaDestroyAllocator(allocator: Allocator) void;
pub extern fn vmaGetAllocatorInfo(allocator: Allocator, p_allocator_info: *AllocatorInfo) void;
pub extern fn vmaGetPhysicalDeviceProperties(
    allocator: Allocator,
    pp_physical_device_properties: *const vk.PhysicalDeviceProperties,
) void;
pub extern fn vmaGetMemoryProperties(
    allocator: Allocator,
    pp_physical_device_memory_properties: ?*const vk.PhysicalDeviceMemoryProperties,
) void;
pub extern fn vmaGetMemoryTypeProperties(
    allocator: Allocator,
    memory_type_index: u32,
    p_flags: *vk.MemoryPropertyFlags,
) void;
pub extern fn vmaSetCurrentFrameIndex(allocator: Allocator, frame_index: u32) void;
pub extern fn vmaCalculateStatistics(allocator: Allocator, p_stats: *TotalStatistics) void;
pub extern fn vmaGetHeapBudgets(allocator: Allocator, p_budgets: *Budget) void;
pub extern fn vmaFindMemoryTypeIndex(
    allocator: Allocator,
    memory_type_bits: u32,
    p_allocation_create_info: *const AllocationCreateInfo,
    p_memory_type_index: *u32,
) vk.Result;
pub extern fn vmaFindMemoryTypeIndexForBufferInfo(
    allocator: Allocator,
    p_buffer_create_info: *const vk.BufferCreateInfo,
    p_allocation_create_info: *const AllocationCreateInfo,
    p_memory_type_index: *u32,
) vk.Result;
pub extern fn vmaFindMemoryTypeIndexForImageInfo(
    allocator: Allocator,
    p_image_create_info: *const vk.ImageCreateInfo,
    p_allocation_create_info: *const AllocationCreateInfo,
    p_memory_type_index: *u32,
) vk.Result;
pub extern fn vmaCreatePool(
    allocator: Allocator,
    p_create_info: *PoolCreateInfo,
    p_pool: ?*Pool,
) vk.Result;
pub extern fn vmaGetPoolStatistics(allocator: Allocator, pool: Pool, p_pool_stats: *Statistics) void;
pub extern fn vmaCalculatePoolStatistics(
    allocator: Allocator,
    pool: Pool,
    pPoolStats: *DetailedStatistics,
) void;
pub extern fn vmaCheckPoolCorruption(allocator: Allocator, pool: Pool) vk.Result;
pub extern fn vmaGetPoolName(allocator: Allocator, pool: Pool, pp_name: ?[*:0]const u8) void;
pub extern fn vmaSetPoolName(allocator: Allocator, pool: Pool, p_name: ?[*:0]const u8) void;
pub extern fn vmaAllocateMemory(
    allocator: Allocator,
    p_vk_memory_requirements: *const vk.MemoryRequirements,
    p_create_info: *const AllocationCreateInfo,
    p_allocation: ?*Allocation,
    p_allocation_info: ?*AllocationInfo,
) vk.Result;
pub extern fn vmaAllocateMemoryPages(
    allocator: Allocator,
    p_vk_memory_requirements: ?*const vk.MemoryRequirements,
    p_create_info: ?*const AllocationCreateInfo,
    allocation_count: usize,
    p_allocations: ?*Allocation,
    p_allocation_info: ?*AllocationInfo,
) vk.Result;
pub extern fn vmaAllocateMemoryForBuffer(
    allocator: Allocator,
    buffer: vk.Buffer,
    p_create_info: *const AllocationCreateInfo,
    p_allocation: ?*Allocation,
    p_allocation_info: ?*AllocationInfo,
) vk.Result;
pub extern fn vmaAllocateMemoryForImage(
    allocator: Allocator,
    image: vk.Image,
    p_create_info: *const AllocationCreateInfo,
    p_allocation: ?*Allocation,
    p_allocation_info: ?*AllocationInfo,
) vk.Result;
pub extern fn vmaFreeMemory(allocator: Allocator, allocation: ?Allocation) void;
pub extern fn vmaFreeMemoryPages(
    allocator: Allocator,
    allocation_count: usize,
    p_allocations: ?*const Allocation,
) void;
pub extern fn vmaGetAllocationInfo(
    allocator: Allocator,
    allocation: Allocation,
    p_allocation_info: *AllocationInfo,
) void;
pub extern fn vmaGetAllocationInfo2(
    allocator: Allocator,
    allocation: Allocation,
    p_allocation_info: *AllocationInfo2,
) void;
pub extern fn vmaSetAllocationUserData(
    allocator: Allocator,
    allocation: Allocation,
    p_user_data: ?*anyopaque,
) void;
pub extern fn vmaSetAllocationName(
    allocator: Allocator,
    allocation: Allocation,
    p_name: ?[*:0]const u8,
) void;
pub extern fn vmaGetAllocationMemoryProperties(
    allocator: Allocator,
    allocation: Allocation,
    p_flags: [*]vk.MemoryPropertyFlags,
) void;
// pub extern fn vmaGetMemoryWin32Handle(allocator: Allocator, allocation: Allocation, HANDLE hTargetProcess, HANDLE*  pHandle) vk.Result;
pub extern fn vmaMapMemory(
    allocator: Allocator,
    allocation: Allocation,
    pp_data: ?[*]*anyopaque,
) vk.Result;
pub extern fn vmaUnmapMemory(allocator: Allocator, allocation: Allocation) void;
pub extern fn vmaFlushAllocation(
    allocator: Allocator,
    allocation: Allocation,
    offset: vk.DeviceSize,
    size: vk.DeviceSize,
) vk.Result;
pub extern fn vmaInvalidateAllocation(
    allocator: Allocator,
    allocation: Allocation,
    offset: vk.DeviceSize,
    size: vk.DeviceSize,
) vk.Result;
pub extern fn vmaFlushAllocations(
    allocator: Allocator,
    allocation_count: u32,
    allocations: ?*const Allocation,
    offsets: ?*const vk.DeviceSize,
    sizes: ?*const vk.DeviceSize,
) vk.Result;
pub extern fn vmaInvalidateAllocations(
    allocator: Allocator,
    allocation_count: u32,
    allocations: ?*const Allocation,
    offsets: ?*const vk.DeviceSize,
    sizes: ?*const vk.DeviceSize,
) vk.Result;
pub extern fn vmaCopyMemoryToAllocation(
    allocator: Allocator,
    p_src_host_pointer: *const anyopaque,
    dst_allocation: Allocation,
    dst_allocation_local_offset: vk.DeviceSize,
    size: vk.DeviceSize,
) vk.Result;
pub extern fn vmaCopyAllocationToMemory(
    allocator: Allocator,
    src_allocation: Allocation,
    src_allocation_local_offset: vk.DeviceSize,
    p_dst_host_pointer: *anyopaque,
    size: vk.DeviceSize,
) vk.Result;
pub extern fn vmaCheckCorruption(allocator: Allocator, memory_type_bits: u32) vk.Result;
pub extern fn vmaBeginDefragmentation(
    allocator: Allocator,
    p_info: *const DefragmentationInfo,
    p_context: ?*DefragmentationContext,
) vk.Result;
pub extern fn vmaEndDefragmentation(
    allocator: Allocator,
    context: DefragmentationContext,
    p_stats: ?*DefragmentationStats,
) void;
pub extern fn vmaBeginDefragmentationPass(
    allocator: Allocator,
    context: DefragmentationContext,
    p_pass_info: *DefragmentationPassMoveInfo,
) vk.Result;
pub extern fn vmaEndDefragmentationPass(
    allocator: Allocator,
    context: DefragmentationContext,
    p_pass_info: *DefragmentationPassMoveInfo,
) vk.Result;
pub extern fn vmaBindBufferMemory(
    allocator: Allocator,
    allocation: Allocation,
    buffer: vk.Buffer,
) vk.Result;
pub extern fn vmaBindBufferMemory2(
    allocator: Allocator,
    allocation: Allocation,
    allocation_local_offset: vk.DeviceSize,
    buffer: vk.Buffer,
    p_next: ?*const anyopaque,
) vk.Result;
pub extern fn vmaBindImageMemory(
    allocator: Allocator,
    allocation: Allocation,
    image: vk.Image,
) vk.Result;
pub extern fn vmaBindImageMemory2(
    allocator: Allocator,
    allocation: Allocation,
    allocation_local_offset: vk.DeviceSize,
    image: vk.Image,
    p_next: ?*const anyopaque,
) vk.Result;
pub extern fn vmaCreateBuffer(
    allocator: Allocator,
    p_buffer_create_info: *const vk.BufferCreateInfo,
    p_allocation_create_info: *const AllocationCreateInfo,
    p_buffer: ?*vk.Buffer,
    p_allocation: ?*Allocation,
    p_allocation_info: ?*AllocationInfo,
) vk.Result;
pub extern fn vmaCreateBufferWithAlignment(
    allocator: Allocator,
    p_buffer_create_info: *const vk.BufferCreateInfo,
    p_allocation_create_info: *const AllocationCreateInfo,
    min_alignment: vk.DeviceSize,
    p_buffer: ?*vk.Buffer,
    p_allocation: ?*Allocation,
    p_allocation_info: ?*AllocationInfo,
) vk.Result;
pub extern fn vmaCreateAliasingBuffer(
    allocator: Allocator,
    allocation: Allocation,
    p_buffer_create_info: *const vk.BufferCreateInfo,
    p_buffer: ?*vk.Buffer,
) vk.Result;
pub extern fn vmaCreateAliasingBuffer2(
    allocator: Allocator,
    allocation: Allocation,
    allocation_local_offset: vk.DeviceSize,
    p_buffer_create_info: *const vk.BufferCreateInfo,
    p_buffer: ?*vk.Buffer,
) vk.Result;
pub extern fn vmaDestroyBuffer(
    allocator: Allocator,
    buffer: ?vk.Buffer,
    allocation: ?Allocation,
) void;
pub extern fn vmaCreateImage(
    allocator: Allocator,
    p_image_create_info: *const vk.ImageCreateInfo,
    p_allocation_create_info: *const AllocationCreateInfo,
    p_image: ?*vk.Image,
    p_allocation: ?*Allocation,
    p_allocation_info: ?*AllocationInfo,
) vk.Result;
pub extern fn vmaCreateAliasingImage(
    allocator: Allocator,
    allocation: Allocation,
    p_image_create_info: *const vk.ImageCreateInfo,
    p_image: ?*vk.Image,
) vk.Result;
pub extern fn vmaCreateAliasingImage2(
    allocator: Allocator,
    allocation: Allocation,
    allocation_local_offset: vk.DeviceSize,
    p_image_create_info: *const vk.ImageCreateInfo,
    p_image: ?*vk.Image,
) vk.Result;
pub extern fn vmaDestroyImage(allocator: Allocator, image: ?vk.Image, allocation: ?Allocation) void;
pub extern fn vmaCreateVirtualBlock(
    p_create_info: *const VirtualBlockCreateInfo,
    p_virtual_block: ?*VirtualBlock,
) vk.Result;
pub extern fn vmaDestroyVirtualBlock(virtual_block: ?VirtualBlock) void;
pub extern fn vmaIsVirtualBlockEmpty(virtual_block: VirtualBlock) vk.Bool32;
pub extern fn vmaGetVirtualAllocationInfo(
    virtual_block: VirtualBlock,
    allocation: VirtualAllocation,
    p_virtual_alloc_info: *VirtualAllocationInfo,
) void;
pub extern fn vmaVirtualAllocate(
    virtual_block: VirtualBlock,
    p_create_info: *const VirtualAllocationCreateInfo,
    p_allocation: ?*VirtualAllocation,
    p_offset: ?*vk.DeviceSize,
) vk.Result;
pub extern fn vmaVirtualFree(virtual_block: VirtualBlock, allocation: ?VirtualAllocation) void;
pub extern fn vmaClearVirtualBlock(virtual_block: VirtualBlock) void;
pub extern fn vmaSetVirtualAllocationUserData(
    virtual_block: VirtualBlock,
    allocation: VirtualAllocation,
    p_user_data: ?*anyopaque,
) void;
pub extern fn vmaGetVirtualBlockStatistics(virtual_block: VirtualBlock, p_stats: *Statistics) void;
pub extern fn vmaCalculateVirtualBlockStatistics(
    virtual_block: VirtualBlock,
    p_stats: *DetailedStatistics,
) void;
pub extern fn vmaBuildVirtualBlockStatsString(
    virtual_block: VirtualBlock,
    pp_stats_string: ?[*][*:0]u8,
    detailed_map: vk.Bool32,
) void;
pub extern fn vmaFreeVirtualBlockStatsString(
    virtual_block: VirtualBlock,
    p_stats_string: ?[*:0]u8,
) void;
pub extern fn vmaBuildStatsString(
    allocator: Allocator,
    pp_stats_string: ?[*][*:0]u8,
    detailed_map: vk.Bool32,
) void;
pub extern fn vmaFreeStatsString(allocator: Allocator, p_stats_string: ?[*:0]u8) void;
