const std = @import("std");
const Allocator = std.mem.Allocator;

const Object = @import("object.zig").Object;

const NamedVariant = @This();

name: []const u8 = undefined,
class_name: []const u8 = undefined,
variant: *Object = undefined,

pub fn deinit(self: *NamedVariant, allocator: Allocator) void {
    allocator.free(self.name);
    allocator.free(self.class_name);
}
