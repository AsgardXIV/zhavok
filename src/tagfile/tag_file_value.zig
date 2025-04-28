const std = @import("std");

pub const TagFileValue = union(enum) {
    string: []const u8,

    pub const Array = struct {
        entries: std.ArrayListUnmanaged(TagFileValue),
    };
};
