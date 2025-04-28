const std = @import("std");
const Allocator = std.mem.Allocator;

const TagFile = @import("TagFile.zig");
const TagFileTypeInfo = @import("TagFileTypeInfo.zig");
const TagFileMemberInfo = @import("TagFileMemberInfo.zig");
const TagValue = @import("tag_value.zig").TagValue;

const TagFileStruct = @This();

type_info: *TagFileTypeInfo,
fields: std.AutoArrayHashMapUnmanaged(usize, TagValue),

pub fn createFromStream(allocator: Allocator, tf: *TagFile, class_index: i32) error{InvalidStruct}!TagFileStruct {
    const resolved_class_index = if (class_index != 0) class_index else tf.readPackedInt(i32) catch return error.InvalidStruct;

    var tfs = TagFileStruct{
        .type_info = &tf.remembered_types.items[@intCast(resolved_class_index)],
        .fields = .{},
    };

    const member_count = countMembers(tf, resolved_class_index);

    const available_members = allocator.alloc(bool, member_count) catch return error.InvalidStruct;
    defer allocator.free(available_members);
    tf.readBitfield(available_members) catch return error.InvalidStruct;

    var first_index: usize = 0;
    tfs.parseStructMembers(allocator, tf, available_members, &first_index, tfs.type_info) catch return error.InvalidStruct;

    return tfs;
}

pub fn free(tfs: *TagFileStruct, allocator: Allocator) void {
    tfs.cleanupFields(allocator);
}

fn parseStructMembers(tfs: *TagFileStruct, allocator: Allocator, tf: *TagFile, bitmap: []bool, first_index: *usize, type_info: *TagFileTypeInfo) !void {
    if (type_info.parent_type_index != 0) {
        try tfs.parseStructMembers(allocator, tf, bitmap, first_index, &tf.remembered_types.items[@intCast(type_info.parent_type_index)]);
    }

    for (type_info.members.items) |*member| {
        const member_index = first_index.*;

        if (bitmap[member_index]) {
            var field_value = try TagValue.createFromStream(allocator, tf, member);
            errdefer field_value.free(allocator);
            try tfs.fields.put(allocator, member_index, field_value);
        }

        first_index.* += 1;
    }
}

fn cleanupFields(tfs: *TagFileStruct, allocator: Allocator) void {
    var iter = tfs.fields.iterator();
    while (iter.next()) |entry| {
        entry.value_ptr.free(allocator);
    }
    tfs.fields.deinit(allocator);
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
