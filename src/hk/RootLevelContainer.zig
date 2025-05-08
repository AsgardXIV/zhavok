const std = @import("std");
const Allocator = std.mem.Allocator;

const NamedVariant = @import("NamedVariant.zig");
const Object = @import("object.zig").Object;

pub const havok_name = "hkRootLevelContainer";

const RootLevelContainer = @This();

named_variants: std.ArrayListUnmanaged(NamedVariant) = .{},

pub fn deinit(self: *RootLevelContainer, allocator: Allocator) void {
    for (self.named_variants.items) |*variant| {
        variant.deinit(allocator);
    }
    self.named_variants.deinit(allocator);
}

pub fn getVariantByName(self: *RootLevelContainer, name: []const u8) !*Object {
    for (self.named_variants.items) |*named_variant| {
        if (std.mem.eql(u8, named_variant.name, name)) {
            return named_variant.variant;
        }
    }
    return error.VariantNotFound;
}

pub fn getVariantByType(self: *RootLevelContainer, type_name: []const u8) !*Object {
    for (self.named_variants.items) |*named_variant| {
        if (std.mem.eql(u8, named_variant.class_name, type_name)) {
            return named_variant.variant;
        }
    }
    return error.VariantNotFound;
}

pub fn getObjectByType(self: *RootLevelContainer, comptime T: type) !*T {
    const type_name = T.havok_name;
    const variant = try self.getVariantByType(type_name);
    const ptr = try variant.as(T);
    return ptr;
}
