const std = @import("std");

pub const tagfile = @import("tagfile.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
