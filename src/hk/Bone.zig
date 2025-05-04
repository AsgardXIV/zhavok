const std = @import("std");
const Allocator = std.mem.Allocator;

const Bone = @This();

pub const havok_name = "hkaBone";

name: []const u8 = undefined,
lock_translation: bool = false,

pub fn deinit(bone: *Bone, allocator: Allocator) void {
    allocator.free(bone.name);
}
