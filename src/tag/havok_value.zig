const std = @import("std");

const HavokTagFile = @import("HavokTagFile.zig");
const HavokObjectTypeMember = @import("HavokObjectTypeMember.zig");
const HavokValueTypes = @import("havok_value_types.zig").HavokValueTypes;

pub const HavokValue = union(enum) {
    byte: u8,
    int: i32,
    real: f32,
    string: []const u8,
    array: []HavokValue,

    pub fn create(
        htf: *HavokTagFile,
        value_type: HavokValueTypes,
    ) !HavokValue {
        const value: HavokValue = switch (value_type) {
            .byte => .{ .byte = try htf.reader.readByte() },
            .int => .{ .int = try htf.readPackedInt(i32) },
            .real => .{ .real = @bitCast(try htf.reader.readInt(u32, .little)) },
            .string => .{ .string = try htf.readString() },
            else => unreachable,
        };

        return value;
    }
};
