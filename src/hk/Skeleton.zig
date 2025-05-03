const std = @import("std");
const Allocator = std.mem.Allocator;

const Skeleton = @This();

pub const havok_name = "hkaSkeleton";

name: ?[]const u8 = null,

pub fn deinit(skel: *Skeleton, allocator: Allocator) void {
    if (skel.name) |n| allocator.free(n);
}
