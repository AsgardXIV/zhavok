const std = @import("std");
const Allocator = std.mem.Allocator;

const Bone = @import("Bone.zig");
const QsTransform = @import("vector_types.zig").QsTransform;

const Skeleton = @This();

pub const havok_name = "hkaSkeleton";

name: ?[]const u8 = null,
parentIndices: std.ArrayListUnmanaged(i16) = .{},
bones: std.ArrayListUnmanaged(Bone) = .{},
referencePose: std.ArrayListUnmanaged(QsTransform) = .{},

pub fn deinit(skel: *Skeleton, allocator: Allocator) void {
    if (skel.name) |n| allocator.free(n);

    skel.parentIndices.deinit(allocator);

    for (skel.bones.items) |*item| {
        item.deinit(allocator);
    }
    skel.bones.deinit(allocator);

    skel.referencePose.deinit(allocator);
}
