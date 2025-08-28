//! Push constant to the GPU

pub const ComputePushConstants = struct {
    data1: @Vector(4, f32),
    data2: @Vector(4, f32),
    data3: @Vector(4, f32),
    data4: @Vector(4, f32),

    pub const zero: ComputePushConstants = .{
        .data1 = .{ 0, 0, 0, 0 },
        .data2 = .{ 0, 0, 0, 0 },
        .data3 = .{ 0, 0, 0, 0 },
        .data4 = .{ 0, 0, 0, 0 },
    };
};
