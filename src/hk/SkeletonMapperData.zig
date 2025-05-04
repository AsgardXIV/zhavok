const std = @import("std");
const Allocator = std.mem.Allocator;

const Skeleton = @import("Skeleton.zig");

const SkeletonMapperData = @This();

const ObjectRef = @import("object_ref.zig").ObjectRef;

pub const havok_name = "hkaSkeletonMapperData";

skeleton_a: ObjectRef(Skeleton) = undefined,
skeleton_b: ObjectRef(Skeleton) = undefined,

pub fn deinit(skel_map_data: *SkeletonMapperData, allocator: Allocator) void {
    _ = skel_map_data;
    _ = allocator;
}
