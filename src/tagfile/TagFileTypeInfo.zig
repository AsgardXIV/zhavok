const std = @import("std");
const TagFileMemberInfo = @import("TagFileMemberInfo.zig");

const references = @import("references.zig");
const TypeInfoReference = references.TypeInfoReference;

const TagFieldTypeInfo = @This();

name: []const u8,
_unk3: i32,
parent_type: ?TypeInfoReference,
members: std.ArrayListUnmanaged(TagFileMemberInfo),
