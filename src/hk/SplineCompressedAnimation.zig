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

block_offsets: std.ArrayListUnmanaged(u32) = .{},
float_block_offsets: std.ArrayListUnmanaged(u32) = .{},
transform_offsets: std.ArrayListUnmanaged(u32) = .{},
float_offsets: std.ArrayListUnmanaged(u32) = .{},

data: std.ArrayListUnmanaged(u8) = .{},

endian: i32 = 0,

pub fn deinit(anim: *SplineCompressedAnimation, allocator: Allocator) void {
    anim.block_offsets.deinit(allocator);
    anim.float_block_offsets.deinit(allocator);
    anim.transform_offsets.deinit(allocator);
    anim.float_offsets.deinit(allocator);

    anim.data.deinit(allocator);
}
