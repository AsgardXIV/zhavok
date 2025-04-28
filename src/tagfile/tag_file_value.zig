const std = @import("std");

pub const TagFileValue = union(enum) {
    byte: u8,
    int: i32,
    array: Array,
    object: i32,
    string: []const u8,

    pub const Array = struct {
        entries: std.ArrayListUnmanaged(TagFileValue),
    };
};
