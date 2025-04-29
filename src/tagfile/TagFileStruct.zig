const std = @import("std");

const TagFileValue = @import("tag_file_value.zig").TagFileValue;
const TagFileTypeInfo = @import("TagFileTypeInfo.zig");

type_info: *TagFileTypeInfo,
fields: std.AutoArrayHashMapUnmanaged(usize, TagFileValue),
