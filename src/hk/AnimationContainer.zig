const std = @import("std");
const Allocator = std.mem.Allocator;

const ReferencedObject = @import("ReferencedObject.zig");
const Skeleton = @import("Skeleton.zig");
const Animation = @import("Animation.zig");

const AnimationContainer = @This();

pub const havok_name = "hkaAnimationContainer";

base: ReferencedObject = .{},
skeletons: std.ArrayListUnmanaged(*Skeleton) = .{},
animations: std.ArrayListUnmanaged(*Animation) = .{},

pub fn deinit(ac: *AnimationContainer, allocator: Allocator) void {
    ac.skeletons.deinit(allocator);
    ac.animations.deinit(allocator);
}
