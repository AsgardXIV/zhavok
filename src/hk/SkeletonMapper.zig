const std = @import("std");
const Allocator = std.mem.Allocator;

const ReferencedObject = @import("ReferencedObject.zig");
const SkeletonMapperData = @import("SkeletonMapperData.zig");

const SkeletonMapper = @This();

pub const havok_name = "hkaSkeletonMapper";

base: ReferencedObject = .{},
mapping: SkeletonMapperData = undefined,

pub fn deinit(skel_map: *SkeletonMapper, allocator: Allocator) void {
    skel_map.mapping.deinit(allocator);
}
