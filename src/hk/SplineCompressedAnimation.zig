const std = @import("std");
const Allocator = std.mem.Allocator;

const Animation = @import("Animation.zig");

const SplineCompressedAnimation = @This();

pub const havok_name = "hkaSplineCompressedAnimation";

base: Animation = .{},

pub fn deinit(anim: *SplineCompressedAnimation, allocator: Allocator) void {
    _ = anim;
    _ = allocator;
}
