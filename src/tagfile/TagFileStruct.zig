const std = @import("std");

const TagFileValue = @import("tag_file_value.zig").TagFileValue;
const TagFileTypeInfo = @import("TagFileTypeInfo.zig");

const references = @import("references.zig");
const TypeInfoReference = references.TypeInfoReference;

const TagFileStruct = @This();

type_info: TypeInfoReference,
fields: std.AutoArrayHashMapUnmanaged(usize, TagFileValue),

pub fn getRawValueByName(tfs: *const TagFileStruct, name: []const u8) ?*TagFileValue {
    var current_index: usize = 0;
    const member_index = getMemberIndex(tfs.type_info.resolved, name, &current_index);
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

fn getMemberIndex(ti: *TagFileTypeInfo, name: []const u8, curent_index: *usize) ?usize {
    if (ti.parent_type) |pt| {
        const parent_index = getMemberIndex(pt.resolved, name, curent_index);
        if (parent_index) |pi| {
            return pi;
        }
    }

    for (ti.members.items) |*member| {
        if (std.mem.eql(u8, member.name, name)) {
            return curent_index.*;
        }
        curent_index.* += 1;
    }

    return null;
}
