const std = @import("std");

const NamedVariant = @import("NamedVariant.zig");

const RootLevelContainer = @This();

pub const havok_name = "hkRootLevelContainer";

named_variants: std.ArrayListUnmanaged(NamedVariant) = .{},

pub fn deinit(rlc: *RootLevelContainer, allocator: std.mem.Allocator) void {
    for (rlc.named_variants.items) |*item| {
        item.deinit(allocator);
    }
    rlc.named_variants.deinit(allocator);
}
