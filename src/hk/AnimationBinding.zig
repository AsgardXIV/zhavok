const std = @import("std");
const Allocator = std.mem.Allocator;

const ReferencedObject = @import("ReferencedObject.zig");

const AnimationBinding = @This();

pub const havok_name = "hkaAnimationBinding";

base: ReferencedObject = .{},
original_skeleton_name: []const u8 = undefined,

pub fn deinit(ab: *AnimationBinding, allocator: Allocator) void {
    allocator.free(ab.original_skeleton_name);
}
