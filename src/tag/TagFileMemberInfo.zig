const std = @import("std");
const Allocator = std.mem.Allocator;

const TagFile = @import("TagFile.zig");
const TagValueTypes = @import("tag_value_types.zig").TagValueTypes;

const TagFileMemberInfo = @This();

name: []const u8,
type: TagValueTypes,
tuple_size: ?i32,
class_name: ?[]const u8,

pub fn createFromStream(tf: *TagFile) !TagFileMemberInfo {
    const name = try tf.readString();
    const raw_type = try tf.readPackedInt(i32);
    const @"type": TagValueTypes = @enumFromInt(raw_type);

    const tuple_size = if (@"type".isTuple()) try tf.readPackedInt(i32) else null;

    const value_type = @"type".getValueType();
    const class_name = if (value_type == .@"struct" or value_type == .object) try tf.readString() else null;

    return .{
        .name = name,
        .type = @"type",
        .tuple_size = tuple_size,
        .class_name = class_name,
    };
}
