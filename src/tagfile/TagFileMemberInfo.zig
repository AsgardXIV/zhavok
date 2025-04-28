const TagFileValueType = @import("tag_file_value_type.zig").TagFileValueType;

name: []const u8,
type: TagFileValueType,
tuple_size: ?i32,
class_name: ?[]const u8,
