const std = @import("std");
const Allocator = std.mem.Allocator;

const HavokTagFile = @import("HavokTagFile.zig");
const HavokValue = @import("havok_value.zig").HavokValue;

const HavokObject = @This();

allocator: Allocator,

pub fn init(allocator: Allocator, htf: *HavokTagFile) !*HavokObject {
    const ho = try allocator.create(HavokObject);
    errdefer allocator.destroy(ho);

    const object_type_idx = try htf.readPackedInt(usize);
    const object_type = htf.remembered_types.items[object_type_idx];

    const member_count = object_type.members.items.len;

    var sfb = std.heap.stackFallback(32, allocator);
    var sfa = sfb.get();
    const available_members: []bool = try sfa.alloc(bool, member_count);
    try htf.readBitfield(available_members);
    defer sfa.free(available_members);

    for (0..member_count) |i| {
        std.log.err("{s} {d}: {any}", .{ object_type.members.items[i].name, i, available_members[i] });
    }

    for (0..member_count) |i| {
        if (available_members[i]) {
            const member = object_type.members.items[i];
            const value = try HavokValue.create(htf, member.value_type);
            _ = value;
        }
    }

    ho.* = .{
        .allocator = allocator,
    };

    return ho;
}

pub fn deinit(ho: *HavokObject) void {
    ho.allocator.destroy(ho);
}
