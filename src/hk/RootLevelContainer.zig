const std = @import("std");
const Allocator = std.mem.Allocator;

const NamedVariant = @import("NamedVariant.zig");

pub const havok_name = "hkRootLevelContainer";

const RootLevelContainer = @This();

named_variants: std.ArrayListUnmanaged(NamedVariant) = .{},

pub fn deinit(self: *RootLevelContainer, allocator: Allocator) void {
    for (self.named_variants.items) |*variant| {
        variant.deinit(allocator);
    }
    self.named_variants.deinit(allocator);
}
