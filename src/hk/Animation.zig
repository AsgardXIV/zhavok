const std = @import("std");
const Allocator = std.mem.Allocator;

const ReferencedObject = @import("ReferencedObject.zig");

const Animation = @This();

pub const havok_name = "hkaAnimation";

base: ReferencedObject = .{},
duration: f32 = 0.0,

pub fn deinit(anim: *Animation, allocator: Allocator) void {
    _ = anim;
    _ = allocator;
}
