const std = @import("std");
const Allocator = std.mem.Allocator;

const serialization = @import("../hk/serialization.zig");

const TagFileStruct = @import("../tagfile/TagFileStruct.zig");

const AnimationContainer = @import("AnimationContainer.zig");
const Bone = @import("Bone.zig");
const RootLevelContainer = @import("RootLevelContainer.zig");
const Skeleton = @import("Skeleton.zig");
const SkeletonMapper = @import("SkeletonMapper.zig");
const SkeletonMapperData = @import("SkeletonMapperData.zig");

pub const Variant = union(enum) {
    invalid: void,
    animation_container: AnimationContainer,
    bone: Bone,
    root_level_container: RootLevelContainer,
    skeleton: Skeleton,
    skeleton_mapper: SkeletonMapper,
    skeleton_mapper_data: SkeletonMapperData,

    pub fn fromStruct(allocator: Allocator, tfs: *TagFileStruct, name: []const u8) !Variant {
        if (std.mem.eql(u8, name, AnimationContainer.havok_name)) {
            var container: AnimationContainer = .{};
            try serialization.populate(allocator, &container, tfs);
            return .{ .animation_container = container };
        } else if (std.mem.eql(u8, name, Bone.havok_name)) {
            var bone: Bone = .{};
            try serialization.populate(allocator, &bone, tfs);
            return .{ .bone = bone };
        } else if (std.mem.eql(u8, name, RootLevelContainer.havok_name)) {
            var rlc: RootLevelContainer = .{};
            try serialization.populate(allocator, &rlc, tfs);
            return .{ .root_level_container = rlc };
        } else if (std.mem.eql(u8, name, Skeleton.havok_name)) {
            var skeleton: Skeleton = .{};
            try serialization.populate(allocator, &skeleton, tfs);
            return .{ .skeleton = skeleton };
        } else if (std.mem.eql(u8, name, SkeletonMapper.havok_name)) {
            var skeleton_mapper: SkeletonMapper = .{};
            try serialization.populate(allocator, &skeleton_mapper, tfs);
            return .{ .skeleton_mapper = skeleton_mapper };
        } else if (std.mem.eql(u8, name, SkeletonMapperData.havok_name)) {
            var skeleton_mapper_data: SkeletonMapperData = .{};
            try serialization.populate(allocator, &skeleton_mapper_data, tfs);
            return .{ .skeleton_mapper_data = skeleton_mapper_data };
        }

        return error.InvalidVariantType;
    }

    pub fn deinit(variant: *Variant, allocator: Allocator) void {
        switch (variant.*) {
            .animation_container => |*ac| ac.deinit(allocator),
            .bone => |*b| b.deinit(allocator),
            .root_level_container => |*rlc| rlc.deinit(allocator),
            .skeleton => |*s| s.deinit(allocator),
            .skeleton_mapper => |*s| s.deinit(allocator),
            .skeleton_mapper_data => |*smd| smd.deinit(allocator),

            else => {},
        }
    }
};
