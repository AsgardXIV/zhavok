const std = @import("std");
const Allocator = std.mem.Allocator;

const TagFile = @import("TagFile.zig");
const TagFileMemberInfo = @import("TagFileMemberInfo.zig");
const TagFileStruct = @import("TagFileStruct.zig");
const TagValueTypes = @import("tag_value_types.zig").TagValueTypes;

pub const TagValue = union(enum) {
    void: void,

    string: []const u8,
    @"struct": TagFileStruct,
    object: i32,

    array_struct: std.ArrayListUnmanaged(TagValue),

    pub fn createFromStream(allocator: Allocator, tf: *TagFile, member_info: *TagFileMemberInfo) error{FailedToParse}!TagValue {
        if (member_info.type.isArray() or member_info.type.isTuple()) {
            const array_size: usize = if (member_info.type.isArray()) tf.readPackedInt(usize) catch error.FailedToParse else @intCast(member_info.tuple_size.?);
            return TagValue.parseArray(allocator, tf, member_info, array_size) catch error.FailedToParse;
        }

        return try TagValue.parseValue(allocator, tf, member_info);
    }

    pub fn free(self: *TagValue, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

    fn parseValue(allocator: std.mem.Allocator, tf: *TagFile, member_info: *TagFileMemberInfo) !TagValue {
        const value_type = member_info.type.getValueType();
        std.log.err("Parsing value type: {s}", .{@tagName(value_type)});
        return switch (value_type) {
            .@"struct" => blk: {
                if (member_info.class_name) |class_name| {
                    const class_index = try tf.findTypeIndex(class_name);
                    const struct_instance = try TagFileStruct.createFromStream(allocator, tf, class_index);
                    errdefer struct_instance.free(allocator);
                    break :blk .{ .@"struct" = struct_instance };
                } else {
                    return error.InvalidType;
                }
            },
            .string => blk: {
                const str = try tf.readString();
                break :blk .{ .string = str };
            },
            .object => blk: {
                const object_index = try tf.readPackedInt(i32);
                break :blk .{ .object = object_index };
            },
            else => error.InvalidType,
        };
    }

    fn parseArray(allocator: std.mem.Allocator, tf: *TagFile, member_info: *TagFileMemberInfo, array_size: usize) !TagValue {
        var array_struct = std.ArrayListUnmanaged(TagValue){};
        errdefer array_struct.deinit(allocator);
        try array_struct.ensureTotalCapacity(allocator, array_size);

        for (0..array_size) |_| {
            const element = try TagValue.createFromStream(allocator, tf, member_info);
            array_struct.appendAssumeCapacity(element);
        }

        return .{
            .array_struct = array_struct,
        };
    }
};
