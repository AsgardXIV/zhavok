const std = @import("std");
const Allocator = std.mem.Allocator;

const ReferencedObject = @import("ReferencedObject.zig");
const Skeleton = @import("Skeleton.zig");
const Animation = @import("Animation.zig");
const SplineCompressedAnimation = @import("SplineCompressedAnimation.zig");

const AnimationContainer = @This();

pub const havok_name = "hkaAnimationContainer";

base: ReferencedObject = .{},
skeletons: std.ArrayListUnmanaged(*Skeleton) = .{},
animations: std.ArrayListUnmanaged(*SplineCompressedAnimation) = .{}, // TODO: This won't always be spline compressed

pub fn deinit(ac: *AnimationContainer, allocator: Allocator) void {
    ac.skeletons.deinit(allocator);
    ac.animations.deinit(allocator);
}

pub fn findSkeletonByName(ac: *AnimationContainer, name: []const u8) !*Skeleton {
    for (ac.skeletons.items) |skel| {
        if (std.mem.eql(u8, skel.name, name)) {
            return skel;
        }
    }
    return error.SkeletonNotFound;
}
