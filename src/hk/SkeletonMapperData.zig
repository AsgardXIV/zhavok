const std = @import("std");
const Allocator = std.mem.Allocator;

const Skeleton = @import("Skeleton.zig");

const SkeletonMapperData = @This();

const Object = @import("object.zig").Object;

pub const havok_name = "hkaSkeletonMapperData";

skeleton_a: *Skeleton = undefined,
skeleton_b: *Skeleton = undefined,

pub fn deinit(skel_map_data: *SkeletonMapperData, allocator: Allocator) void {
    _ = skel_map_data;
    _ = allocator;
}
