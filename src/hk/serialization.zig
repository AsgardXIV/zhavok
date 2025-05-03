const std = @import("std");
const Allocator = std.mem.Allocator;

const Variant = @import("variant.zig").Variant;

const TagFile = @import("../tagfile/TagFile.zig");
const TagFileStruct = @import("../tagfile/TagFileStruct.zig");
const TagFileValue = @import("../tagfile/tag_file_value.zig").TagFileValue;

pub const Error = error{
    InvalidTargetType,
    InvalidSourceType,
    InvalidStructType,
    InvalidVariantType,
    InvalidFieldName,
    CustomDeserializeFailed,
    OutOfMemory,
};

pub fn populate(allocator: Allocator, target: anytype, source: anytype) Error!void {
    if (@typeInfo(@TypeOf(target)) != .pointer) {
        return Error.InvalidTargetType;
    }

    if (@typeInfo(@TypeOf(source)) != .pointer) {
        return Error.InvalidSourceType;
    }

    const TargetType = @typeInfo(@TypeOf(target)).pointer.child;
    const SourceType = @typeInfo(@TypeOf(source)).pointer.child;

    const tti = @typeInfo(TargetType);

    // Usually we can use this generic top level function to populate the struct.
    // However, if the struct has a custom deserialize function, we need to call that instead.
    if (tti == .@"struct" or tti == .@"union") {
        if (@hasDecl(TargetType, "havokDeserialize")) {
            const val = TargetType.havokDeserialize(allocator, source) catch return Error.CustomDeserializeFailed;
            target.* = val;
            return;
        }
    }

    switch (tti) {
        .@"struct" => {
            if (SourceType == TagFileStruct) {
                try populateStruct(allocator, target, source);
            } else if (SourceType == TagFileValue) {
                switch (source.*) {
                    .@"struct" => |*s| try populateStruct(allocator, target, s),
                    .array => |*a| {
                        if (@hasDecl(TargetType, "Slice")) {
                            if (@typeInfo(TargetType.Slice) == .pointer) {
                                const ChildType = @typeInfo(TargetType.Slice).pointer.child;

                                for (0..a.entries.items.len) |i| {
                                    var value: ChildType = .{};
                                    try populate(allocator, &value, &a.entries.items[i]);
                                    try target.append(allocator, value);
                                }
                            }
                        }
                    },
                    .object => |*o| try populateStruct(allocator, target, o.resolved),
                    else => return Error.InvalidStructType,
                }
            } else {
                std.log.err("Invalid source type: {s}", .{@typeName(SourceType)});
            }
        },
        .pointer => |*p| {
            if (p.size == .one) {
                const new_value = allocator.create(p.child) catch return Error.OutOfMemory;
                errdefer allocator.destroy(new_value);

                try populate(allocator, new_value, source);

                target.* = new_value;
            } else {
                try populateBasicValue(allocator, target, source);
            }
        },
        .optional => |*o| {
            var temp_value: o.child = if (@typeInfo(o.child) == .@"struct")
                .{}
            else
                @as(o.child, undefined);

            try populate(allocator, &temp_value, source);

            target.* = temp_value;
        },
        else => {
            try populateBasicValue(allocator, target, source);
        },
    }
}

fn populateStruct(allocator: Allocator, target: anytype, source: *TagFileStruct) Error!void {
    const tti = @typeInfo(@typeInfo(@TypeOf(target)).pointer.child);

    if (tti != .@"struct") {
        @compileError("TargetType must be a struct");
    }

    const target_struct = tti.@"struct";

    inline for (target_struct.fields) |field| {
        const havok_name = try zigNameToHavokName(allocator, field.name);
        defer allocator.free(havok_name);

        const svo = source.getRawValueByName(havok_name);
        if (svo) |source_value| {
            const target_field = &@field(target, field.name);
            try populate(allocator, target_field, source_value);
        }
    }
}

fn populateBasicValue(allocator: Allocator, target: anytype, source: *TagFileValue) Error!void {
    const TargetType = @typeInfo(@TypeOf(target)).pointer.child;

    const tti = @typeInfo(TargetType);

    switch (source.*) {
        .string => |*s| {
            if (tti == .pointer and tti.pointer.child == u8) {
                target.* = try allocator.dupe(u8, s.*);
            }
        },
        else => {
            std.log.err("Invalid source type: {s}", .{@tagName(source.*)});
            @breakpoint();
        },
    }
}

fn zigNameToHavokName(allocator: Allocator, str: []const u8) ![]const u8 {
    var buffer: std.ArrayListUnmanaged(u8) = .{};
    try buffer.ensureTotalCapacityPrecise(allocator, str.len);
    defer buffer.deinit(allocator);

    var last_was_underscore = false;
    for (str) |c| {
        if (c == '_') {
            last_was_underscore = true;
        } else {
            const final_char = if (last_was_underscore) std.ascii.toUpper(c) else c;
            last_was_underscore = false;
            buffer.appendAssumeCapacity(final_char);
        }
    }

    const result = try allocator.dupe(u8, buffer.items);

    return result;
}

test "pop" {
    const RootLevelContainer = @import("RootLevelContainer.zig");

    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().openFile("resources/skeleton.tag", .{ .mode = .read_only });
    defer file.close();

    const file_data = try file.readToEndAlloc(allocator, 1 << 20);
    defer allocator.free(file_data);

    const tf = try TagFile.init(allocator, file_data);
    defer tf.deinit();

    var root = try tf.getRootObject();

    var result: RootLevelContainer = .{};
    defer result.deinit(allocator);
    try populate(allocator, &result, &root);
}
