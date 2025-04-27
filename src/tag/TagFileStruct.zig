const std = @import("std");
const Allocator = std.mem.Allocator;

const TagFile = @import("TagFile.zig");
const TagFileTypeInfo = @import("TagFileTypeInfo.zig");
const TagFileMemberInfo = @import("TagFileMemberInfo.zig");

const TagFileStruct = @This();

type_info: *TagFileTypeInfo,

pub fn createFromStream(allocator: Allocator, tf: *TagFile, class_index: i32) !TagFileStruct {
    const resolved_class_index = if (class_index != 0) class_index else try tf.readPackedInt(i32);

    var tfs = TagFileStruct{
        .type_info = &tf.remembered_types.items[@intCast(resolved_class_index)],
    };

    const member_count = countMembers(tf, resolved_class_index);

    const available_members = try allocator.alloc(bool, member_count);
    defer allocator.free(available_members);
    try tf.readBitfield(available_members);

    var first_index: usize = 0;
    try tfs.parseStructMembers(tf, available_members, &first_index, tfs.type_info);

    return tfs;
}

pub fn free(tfs: *TagFileStruct, allocator: Allocator) void {
    _ = allocator;
    _ = tfs;
}

fn parseStructMembers(tfs: *TagFileStruct, tf: *TagFile, bitmap: []bool, first_index: *usize, type_info: *TagFileTypeInfo) !void {
    if (type_info.parent_type_index != 0) {
        try tfs.parseStructMembers(tf, bitmap, first_index, &tf.remembered_types.items[@intCast(type_info.parent_type_index)]);
    }

    for (type_info.members.items) |*member| {
        const member_index = first_index.*;

        if (bitmap[member_index]) {
            try tfs.parseField(member);
        }

        first_index.* += 1;
    }
}

fn parseField(tfs: *TagFileStruct, field: *TagFileMemberInfo) !void {
    _ = tfs;
    _ = field;
}

fn countMembers(tf: *TagFile, class_index: i32) usize {
    var count: usize = 0;
    var current_index = class_index;

    while (current_index != 0) {
        const type_info = &tf.remembered_types.items[@intCast(current_index)];
        count += type_info.members.items.len;
        current_index = type_info.parent_type_index;
    }

    return count;
}
