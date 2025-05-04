const std = @import("std");
const Allocator = std.mem.Allocator;

const SkeletonMapperData = @import("SkeletonMapperData.zig");

const SkeletonMapper = @This();

pub const havok_name = "hkaSkeletonMapper";

mapping: SkeletonMapperData = undefined,

pub fn deinit(skel_map: *SkeletonMapper, allocator: Allocator) void {
    skel_map.mapping.deinit(allocator);
}
