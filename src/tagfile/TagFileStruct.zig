const std = @import("std");

const TagFileValue = @import("tag_file_value.zig").TagFileValue;
const TagFileTypeInfo = @import("TagFileTypeInfo.zig");

const TagFileStruct = @This();

type_info: *TagFileTypeInfo,
fields: std.AutoArrayHashMapUnmanaged(usize, TagFileValue),

pub fn getRawValueByName(tfs: *const TagFileStruct, name: []const u8) ?*TagFileValue {
    const member_index = getMemberIndex(tfs.type_info, name, 0);
    if (member_index) |mi| {
        const field = tfs.fields.getEntry(mi);
        if (field) |f| {
            return f.value_ptr;
        }
    }

    return null;
}

pub fn getValueByName(tfs: *const TagFileStruct, name: []const u8, comptime tag: std.meta.Tag(TagFileValue)) ?*@FieldType(TagFileValue, @tagName(tag)) {
    const raw_value_opt = getRawValueByName(tfs, name);

    if (raw_value_opt) |raw_value| {
        if (raw_value.* != tag) {
            @panic("Field type mismatch");
        }

        return @ptrCast(raw_value);
    }

    return null;
}

fn getMemberIndex(ti: *TagFileTypeInfo, name: []const u8, count: usize) ?usize {
    if (ti.parent_type) |pt| {
        const parent_index = getMemberIndex(pt, name, count);
        if (parent_index) |pi| {
            return count + pi;
        }
    }

    for (ti.members.items, 0..) |*member, i| {
        if (std.mem.eql(u8, member.name, name)) {
            return count + i;
        }
    }

    return null;
}
