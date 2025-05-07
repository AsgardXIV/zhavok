const std = @import("std");
const Allocator = std.mem.Allocator;

const BaseObject = @import("BaseObject.zig");
const ReferencedObject = @import("ReferencedObject.zig");
const RootLevelContainer = @import("RootLevelContainer.zig");
const AnimationContainer = @import("AnimationContainer.zig");
const Animation = @import("Animation.zig");
const SplineCompressedAnimation = @import("SplineCompressedAnimation.zig");
const AnimationBinding = @import("AnimationBinding.zig");
const Skeleton = @import("Skeleton.zig");
const SkeletonMapper = @import("SkeletonMapper.zig");

pub const Object = union(enum) {
    unresolved: void,

    base_object: *BaseObject,
    referenced_object: *ReferencedObject,

    root_level_container: *RootLevelContainer,

    animation_container: *AnimationContainer,
    animation: *Animation,
    spline_compressed_animation: *SplineCompressedAnimation,
    animation_binding: *AnimationBinding,
    skeleton: *Skeleton,
    skeleton_mapper: *SkeletonMapper,

    pub fn deinit(object: *Object, allocator: Allocator) void {
        switch (object.*) {
            .referenced_object => |obj| {
                allocator.destroy(obj);
            },
            .root_level_container => |obj| {
                obj.deinit(allocator);
                allocator.destroy(obj);
            },
            .animation_container => |obj| {
                obj.deinit(allocator);
                allocator.destroy(obj);
            },
            .animation => |obj| {
                obj.deinit(allocator);
                allocator.destroy(obj);
            },
            .spline_compressed_animation => |obj| {
                obj.deinit(allocator);
                allocator.destroy(obj);
            },
            .animation_binding => |obj| {
                obj.deinit(allocator);
                allocator.destroy(obj);
            },
            .skeleton => |obj| {
                obj.deinit(allocator);
                allocator.destroy(obj);
            },
            .skeleton_mapper => |obj| {
                obj.deinit(allocator);
                allocator.destroy(obj);
            },
            else => {},
        }
    }

    pub fn getAs(object: *Object, comptime T: type) !*T {
        return switch (object.*) {
            .unresolved => error.UnresolvedObject,
            inline else => |obj| if (@TypeOf(obj) == *T)
                obj
            else
                error.InvalidTargetType,
        };
    }
};
