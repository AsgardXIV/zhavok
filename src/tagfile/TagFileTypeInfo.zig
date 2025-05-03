const std = @import("std");
const TagFileMemberInfo = @import("TagFileMemberInfo.zig");

const TagFieldTypeInfo = @This();

name: []const u8,
_unk3: i32,
parent_type_index: i32,
parent_type: ?*TagFieldTypeInfo,
members: std.ArrayListUnmanaged(TagFileMemberInfo),
