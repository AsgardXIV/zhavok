const std = @import("std");
const Allocator = std.mem.Allocator;

const ObjectRef = @import("object_ref.zig").ObjectRef;

const NamedVariant = @This();

name: []const u8 = undefined,
class_name: []const u8 = undefined,
variant: ObjectRef(void) = undefined,

pub fn deinit(self: *NamedVariant, allocator: Allocator) void {
    allocator.free(self.name);
    allocator.free(self.class_name);
}
