const std = @import("std");
const Allocator = std.mem.Allocator;

const Skeleton = @import("Skeleton.zig");

const SkeletonMapperData = @This();

pub const havok_name = "hkaSkeletonMapperData";

skeleton_a: *Skeleton = undefined,
skeleton_b: *Skeleton = undefined,

pub fn deinit(skel_map_data: *SkeletonMapperData, allocator: Allocator) void {
    _ = skel_map_data;
    _ = allocator;
}
