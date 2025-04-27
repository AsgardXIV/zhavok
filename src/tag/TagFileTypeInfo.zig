const std = @import("std");
const Allocator = std.mem.Allocator;

const TagFile = @import("TagFile.zig");
const TagFileMemberInfo = @import("TagFileMemberInfo.zig");
const TagValueTypes = @import("tag_value_types.zig").TagValueTypes;

const TagFileTypeInfo = @This();

name: []const u8,
_unk3: i32,
parent_type_index: i32,
members: std.ArrayListUnmanaged(TagFileMemberInfo),

pub fn createFromStream(allocator: Allocator, tf: *TagFile) !TagFileTypeInfo {
    const name = try tf.readString();
    const _unk3 = try tf.readPackedInt(i32);
    const parent_type_index = try tf.readPackedInt(i32);

    var members: std.ArrayListUnmanaged(TagFileMemberInfo) = .{};
    const members_count = try tf.readPackedInt(usize);

    try members.ensureTotalCapacity(allocator, members_count);

    for (0..members_count) |_| {
        const member = try TagFileMemberInfo.createFromStream(tf);
        members.appendAssumeCapacity(member);
    }

    return .{
        .name = name,
        ._unk3 = _unk3,
        .parent_type_index = parent_type_index,
        .members = members,
    };
}

pub fn free(tfi: *TagFileTypeInfo, allocator: Allocator) void {
    tfi.members.deinit(allocator);
}

pub fn voidType(allocator: Allocator) !TagFileTypeInfo {
    var tfi = TagFileTypeInfo{
        .name = "BuiltinVoidType",
        ._unk3 = 0,
        .parent_type_index = 0,
        .members = .{},
    };

    const tfm = TagFileMemberInfo{
        .name = "void",
        .type = TagValueTypes.void,
        .tuple_size = null,
        .class_name = null,
    };

    try tfi.members.append(allocator, tfm);

    return tfi;
}
