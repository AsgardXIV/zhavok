const std = @import("std");

const TagFileValue = @import("tag_file_value.zig").TagFileValue;
const TagFileTypeInfo = @import("TagFileTypeInfo.zig");

const TagFileStruct = @This();

type_info: *TagFileTypeInfo,
fields: std.AutoArrayHashMapUnmanaged(usize, TagFileValue),

pub fn getRawValueByName(tfs: *const TagFileStruct, name: []const u8) !*TagFileValue {
    var field_iter = tfs.fields.iterator();
    while (field_iter.next()) |field| {
        const member_info = &tfs.type_info.members.items[field.key_ptr.*];
        if (std.mem.eql(u8, member_info.name, name)) {
            return field.value_ptr;
        }
    }

    return error.InvalidFieldName;
}

pub fn getValueByName(tfs: *const TagFileStruct, name: []const u8, comptime tag: std.meta.Tag(TagFileValue)) !*@FieldType(TagFileValue, @tagName(tag)) {
    const raw_value = try getRawValueByName(tfs, name);

    if (raw_value.* != tag) {
        return error.FieldTypeMismatch;
    }

    return @ptrCast(raw_value);
}
