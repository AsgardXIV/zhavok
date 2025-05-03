const std = @import("std");
const Allocator = std.mem.Allocator;

const serialization = @import("../hk/serialization.zig");

const TagFileStruct = @import("../tagfile/TagFileStruct.zig");

const AnimationContainer = @import("AnimationContainer.zig");
const RootLevelContainer = @import("RootLevelContainer.zig");
const Skeleton = @import("Skeleton.zig");
const SkeletonMapper = @import("SkeletonMapper.zig");

pub const Variant = union(enum) {
    invalid: void,
    animation_container: AnimationContainer,
    root_level_container: RootLevelContainer,
    skeleton: Skeleton,
    skeleton_mapper: SkeletonMapper,

    pub fn fromStruct(allocator: Allocator, tfs: *TagFileStruct, name: []const u8) !Variant {
        if (std.mem.eql(u8, name, AnimationContainer.havok_name)) {
            var container: AnimationContainer = .{};
            try serialization.populate(allocator, &container, tfs);
            return .{ .animation_container = container };
        } else if (std.mem.eql(u8, name, Skeleton.havok_name)) {
            var skeleton: Skeleton = .{};
            try serialization.populate(allocator, &skeleton, tfs);
            return .{ .skeleton = skeleton };
        } else if (std.mem.eql(u8, name, SkeletonMapper.havok_name)) {
            var skeleton_mapper: SkeletonMapper = .{};
            try serialization.populate(allocator, &skeleton_mapper, tfs);
            return .{ .skeleton_mapper = skeleton_mapper };
        } else if (std.mem.eql(u8, name, RootLevelContainer.havok_name)) {
            var rlc: RootLevelContainer = .{};
            try serialization.populate(allocator, &rlc, tfs);
            return .{ .root_level_container = rlc };
        }

        return error.InvalidVariantType;
    }

    pub fn deinit(variant: *Variant, allocator: Allocator) void {
        switch (variant.*) {
            .root_level_container => |*rlc| rlc.deinit(allocator),
            .skeleton_mapper => |*s| s.deinit(allocator),
            .skeleton => |*s| s.deinit(allocator),
            .animation_container => |*ac| ac.deinit(allocator),
            else => {},
        }
    }
};
