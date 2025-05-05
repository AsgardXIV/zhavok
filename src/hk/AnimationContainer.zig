const std = @import("std");
const Allocator = std.mem.Allocator;

const Skeleton = @import("Skeleton.zig");

const AnimationContainer = @This();

pub const havok_name = "hkaAnimationContainer";

skeletons: std.ArrayListUnmanaged(*Skeleton) = .{},

pub fn deinit(ac: *AnimationContainer, allocator: Allocator) void {
    ac.skeletons.deinit(allocator);
}
