const std = @import("std");

const TagFileStruct = @import("TagFileStruct.zig");

pub const TagFileValue = union(enum) {
    byte: u8,
    int: i32,
    real: f32,
    array: Array,
    object: Object,
    string: []const u8,
    @"struct": TagFileStruct,
    vec4: Vec4,
    vec8: Vec8,
    vec12: Vec12,
    vec16: Vec16,

    pub const Object = struct {
        object_id: i32,
        resolved: *TagFileStruct,
    };

    pub const Array = struct {
        entries: std.ArrayListUnmanaged(TagFileValue) = .{},
    };

    pub const Vec4 = extern struct {
        x: f32 align(1),
        y: f32 align(1),
        z: f32 align(1),
        w: f32 align(1),
    };

    pub const Vec8 = extern struct {
        v: [2]Vec4 align(1),
    };

    pub const Vec12 = extern struct {
        v: [3]Vec4 align(1),
    };

    pub const Vec16 = extern struct {
        v: [4]Vec4 align(1),
    };
};
