const std = @import("std");
const Allocator = std.mem.Allocator;

const ReferencedObject = @import("ReferencedObject.zig");

const Animation = @This();

pub const havok_name = "hkaAnimation";

pub const AnimationType = enum(u32) {
    unknown = 0,
    interleaved = 1,
    mirrored = 2,
    spline_compressed = 3,
    quantized_compressed = 4,
    predictive_compressed = 5,
    reference_pose = 6,
};

base: ReferencedObject = .{},
type: AnimationType = .unknown,
duration: f32 = 0.0,
number_of_transform_tracks: u32 = 0,
number_of_float_tracks: u32 = 0,

pub fn deinit(anim: *Animation, allocator: Allocator) void {
    _ = anim;
    _ = allocator;
}
