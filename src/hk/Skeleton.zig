const std = @import("std");
const Allocator = std.mem.Allocator;

const Bone = @import("Bone.zig");
const QsTransform = @import("vector_types.zig").QsTransform;

const Skeleton = @This();

pub const havok_name = "hkaSkeleton";

name: []const u8 = undefined,
parent_indices: std.ArrayListUnmanaged(i16) = .{},
bones: std.ArrayListUnmanaged(Bone) = .{},
reference_pose: std.ArrayListUnmanaged(QsTransform) = .{},
reference_floats: std.ArrayListUnmanaged(f32) = .{},
float_slots: std.ArrayListUnmanaged([]const u8) = .{},

pub fn deinit(skel: *Skeleton, allocator: Allocator) void {
    allocator.free(skel.name);

    skel.parent_indices.deinit(allocator);

    for (skel.bones.items) |*bone| {
        bone.deinit(allocator);
    }
    skel.bones.deinit(allocator);

    skel.reference_pose.deinit(allocator);

    skel.reference_floats.deinit(allocator);

    for (skel.float_slots.items) |slot| {
        allocator.free(slot);
    }
    skel.float_slots.deinit(allocator);
}
