// pub const Vec3f = [3]f32;

pub fn Vec(comptime T: type, size: comptime_int) type {
    // TODO: Guard against non numeric and float.

    const handle = [size]T;

    return struct {
        handle: @TypeOf(handle),

        const Self = @This();

        pub fn add(self: Self, other: Self) Self {
            var new: Self = [1]T{0} ** size;

            for (0..size) |index| {
                new.handle[index] = self.handle[index] + other.handle[index];
            }

            return new;
        }
    };
}

const std = @import("std");
