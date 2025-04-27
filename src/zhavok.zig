const std = @import("std");

pub const tag = @import("tag.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
