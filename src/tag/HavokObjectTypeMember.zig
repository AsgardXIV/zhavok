const std = @import("std");
const Allocator = std.mem.Allocator;

const HavokTagFile = @import("HavokTagFile.zig");
const HavokValueTypes = @import("havok_value_types.zig").HavokValueTypes;

const HavokObjectTypeMember = @This();

allocator: Allocator,
name: []const u8,
value_type: HavokValueTypes,
tuple_size: u32 = 0,
type_name: []const u8,

pub fn init(allocator: Allocator, htf: *HavokTagFile) !*HavokObjectTypeMember {
    const hom = try allocator.create(HavokObjectTypeMember);
    errdefer allocator.destroy(hom);

    const name = try htf.readString();

    const value_type_raw = try htf.readPackedInt(u32);
    const value_type: HavokValueTypes = @enumFromInt(value_type_raw);

    const base_type = value_type.getBaseType();

    const tuple_size: u32 = if (base_type == HavokValueTypes.tuple)
        try htf.readPackedInt(u32)
    else
        0;

    const type_name = if (base_type == HavokValueTypes.@"struct" or base_type == HavokValueTypes.object)
        try htf.readString()
    else
        "";

    hom.* = .{
        .allocator = allocator,
        .name = name,
        .value_type = value_type,
        .tuple_size = tuple_size,
        .type_name = type_name,
    };

    return hom;
}

pub fn deinit(hom: *HavokObjectTypeMember) void {
    hom.allocator.destroy(hom);
}
