const std = @import("std");
const Allocator = std.mem.Allocator;

const ReferencedObject = @import("ReferencedObject.zig");
const Animation = @import("Animation.zig");
const SplineCompressedAnimation = @import("SplineCompressedAnimation.zig");

const AnimationBinding = @This();

pub const havok_name = "hkaAnimationBinding";

pub const BlendHint = enum(u8) {
    normal = 0,
    additive_deprecated = 1,
    additive = 2,
};

base: ReferencedObject = .{},
original_skeleton_name: []const u8 = undefined,
animation: *SplineCompressedAnimation = undefined, // TODO: This won't always be spline compressed
transform_track_to_bone_indices: std.ArrayListUnmanaged(i16) = .{},
float_track_to_float_slot_indices: std.ArrayListUnmanaged(i16) = .{},
partition_indices: std.ArrayListUnmanaged(i16) = .{},
blend_hint: BlendHint = .normal,

pub fn deinit(ab: *AnimationBinding, allocator: Allocator) void {
    allocator.free(ab.original_skeleton_name);
    ab.transform_track_to_bone_indices.deinit(allocator);
    ab.float_track_to_float_slot_indices.deinit(allocator);
    ab.partition_indices.deinit(allocator);
}
