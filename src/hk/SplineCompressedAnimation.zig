const std = @import("std");
const Allocator = std.mem.Allocator;

const Animation = @import("Animation.zig");

const SplineCompressedAnimation = @This();

pub const havok_name = "hkaSplineCompressedAnimation";
pub const animation_type: Animation.AnimationType = .spline_compressed;

base: Animation = .{},

num_frames: u32 = 0,

num_blocks: u32 = 0,
max_frames_per_block: u32 = 0,
mask_and_quantization_size: u32 = 0,
block_duration: f32 = 0.0,
block_inverse_duration: f32 = 0.0,
frame_duration: f32 = 0.0,

block_offsets: []u32 = &[_]u32{},
float_block_offsets: []u32 = &[_]u32{},
transform_offsets: []u32 = &[_]u32{},
float_offsets: []u32 = &[_]u32{},

data: []u8 = &[_]u8{},

endian: i32 = 0,

pub fn deinit(anim: *SplineCompressedAnimation, allocator: Allocator) void {
    allocator.free(anim.block_offsets);
    allocator.free(anim.float_block_offsets);
    allocator.free(anim.transform_offsets);
    allocator.free(anim.float_offsets);

    allocator.free(anim.data);
}
