const std = @import("std");
const Allocator = std.mem.Allocator;

const Variant = @import("variant.zig").Variant;

const TagFileValue = @import("../tagfile/tag_file_value.zig").TagFileValue;
const TagFileStruct = @import("../tagfile/TagFileStruct.zig");

const NamedVariant = @This();

pub const havok_name = "hkRootLevelContainerNamedVariant";

name: []const u8 = undefined,
class_name: []const u8 = undefined,
variant: Variant = undefined,

pub fn havokDeserialize(allocator: Allocator, tfv: *TagFileValue) !NamedVariant {
    const tfs = &tfv.*.@"struct";

    const name = tfs.getValueByName("name", .string) orelse return error.InvalidNamedVariant;
    const class_name = tfs.getValueByName("className", .string) orelse return error.InvalidNamedVariant;
    const variant = tfs.getValueByName("variant", .object) orelse return error.InvalidNamedVariant;

    const variant_value = try Variant.fromStruct(allocator, variant.resolved, class_name.*);

    return .{
        .name = try allocator.dupe(u8, name.*),
        .class_name = try allocator.dupe(u8, class_name.*),
        .variant = variant_value,
    };
}

pub fn deinit(
    nv: *NamedVariant,
    allocator: std.mem.Allocator,
) void {
    allocator.free(nv.name);
    allocator.free(nv.class_name);
    nv.variant.deinit(allocator);
}
