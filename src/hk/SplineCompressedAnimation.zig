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

block_offsets: []u32 = undefined,
float_block_offsets: []u32 = undefined,
transform_offsets: []u32 = undefined,
float_offsets: []u32 = undefined,

data: []u8 = undefined,

endian: i32 = 0,

pub fn deinit(anim: *SplineCompressedAnimation, allocator: Allocator) void {
    allocator.free(anim.block_offsets);
    allocator.free(anim.float_block_offsets);
    allocator.free(anim.transform_offsets);
    allocator.free(anim.float_offsets);

    allocator.free(anim.data);
}
