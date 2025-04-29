const std = @import("std");

const TagFileValue = @import("tag_file_value.zig").TagFileValue;

class_index: i32,
fields: std.AutoArrayHashMapUnmanaged(usize, TagFileValue),
