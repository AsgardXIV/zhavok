const std = @import("std");
const Allocator = std.mem.Allocator;

const VoidType = @import("VoidType.zig");
const BaseObject = @import("BaseObject.zig");
const ReferencedObject = @import("ReferencedObject.zig");
const RootLevelContainer = @import("RootLevelContainer.zig");
const AnimationContainer = @import("AnimationContainer.zig");
const Skeleton = @import("Skeleton.zig");
const SkeletonMapper = @import("SkeletonMapper.zig");

pub const Object = union(enum) {
    unresolved: void,

    void_type: *VoidType,

    base_object: *BaseObject,
    referenced_object: *ReferencedObject,

    root_level_container: *RootLevelContainer,

    animation_container: *AnimationContainer,
    skeleton: *Skeleton,
    skeleton_mapper: *SkeletonMapper,

    pub fn deinit(object: *Object, allocator: Allocator) void {
        switch (object.*) {
            .void_type => {},
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

    pub fn getPtr(object: *Object) !*anyopaque {
        return switch (object.*) {
            .unresolved => error.UnresolvedObject,
            inline else => |obj| obj,
        };
    }
};
