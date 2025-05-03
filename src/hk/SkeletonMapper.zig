const std = @import("std");
const Allocator = std.mem.Allocator;

const SkeletonMapper = @This();

pub const havok_name = "hkaSkeletonMapper";

pub fn deinit(skel_map: *SkeletonMapper, allocator: Allocator) void {
    _ = skel_map;
    _ = allocator;
}
