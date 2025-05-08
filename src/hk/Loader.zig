const std = @import("std");
const Allocator = std.mem.Allocator;

const TagFile = @import("../tagfile/TagFile.zig");
const TagFileStruct = @import("../tagfile/TagFileStruct.zig");
const TagFileValue = @import("../tagfile/tag_file_value.zig").TagFileValue;

const RootLevelContainer = @import("RootLevelContainer.zig");

const Object = @import("object.zig").Object;

const Loader = @This();

pub const Error = error{
    InvalidTagFile,
    InvalidTargetType,
    NotImplemented,
    OutOfMemory,
    UnresolvedObject,
    NoDefaultValue,
};

allocator: Allocator,
objects: std.ArrayListUnmanaged(Object),
tf: *TagFile,

pub fn init(allocator: Allocator) Error!*Loader {
    const loader = try allocator.create(Loader);

    loader.* = .{
        .allocator = allocator,
        .objects = .{},
        .tf = undefined,
    };

    return loader;
}

pub fn deinit(loader: *Loader) void {
    loader.cleanupObjects();
    loader.allocator.destroy(loader);
}

pub fn loadFromTagFile(loader: *Loader, tf: *TagFile) Error!*RootLevelContainer {
    try loader.populateFromTagFile(tf);

    for (loader.objects.items) |*object| {
        if (object.* == .root_level_container) {
            return object.root_level_container;
        }
    }

    return error.InvalidTagFile;
}

fn populateFromTagFile(loader: *Loader, tf: *TagFile) Error!void {
    loader.tf = tf;

    const object_count = tf.remembered_objects.items.len;
    try loader.objects.ensureTotalCapacityPrecise(loader.allocator, object_count);

    for (0..object_count) |_| {
        loader.objects.appendAssumeCapacity(.{
            .unresolved = undefined,
        });
    }

    for (0..object_count) |i| {
        _ = try loader.resolveObject(@intCast(i));
    }
}

fn populateObject(loader: *Loader, object: *Object, tfs: *TagFileStruct) Error!void {
    const type_info = tfs.type_info.resolved;
    const type_name = type_info.name;

    inline for (@typeInfo(Object).@"union".fields) |field| {
        const PointerType = field.type;
        const pointer_type_info = @typeInfo(PointerType);
        if (pointer_type_info == .pointer) {
            const ObjectType = pointer_type_info.pointer.child;
            const tag_name = field.name;

            if (std.mem.eql(u8, type_name, ObjectType.havok_name)) {
                const new_obj = try loader.allocator.create(ObjectType);
                errdefer loader.allocator.destroy(new_obj);
                new_obj.* = .{};
                try populateStruct(loader, new_obj, tfs);
                object.* = @unionInit(Object, tag_name, new_obj);
                return;
            }
        }
    }
}

fn populateStruct(loader: *Loader, data: anytype, tfs: *TagFileStruct) Error!void {
    const TargetType = @TypeOf(data);
    const target_type_info = @typeInfo(TargetType);

    const StructType = target_type_info.pointer.child;
    const struct_info = @typeInfo(StructType).@"struct";

    inline for (struct_info.fields) |*field| {
        if (@hasField(StructType, "base") and std.mem.eql(u8, field.name, "base")) {
            try populateStruct(loader, &data.base, tfs);
        } else {
            const havok_name = try zigNameToHavokName(loader.allocator, field.name);
            defer loader.allocator.free(havok_name);

            const svo = tfs.getRawValueByName(havok_name);

            if (svo) |source_value| {
                const target_field = &@field(data, field.name);
                try loader.populateValue(target_field, source_value);
            }
        }
    }
}

fn populateValue(loader: *Loader, target: anytype, source: *TagFileValue) Error!void {
    const TargetType = @typeInfo(@TypeOf(target)).pointer.child;

    const tti = @typeInfo(TargetType);

    if (tti == .optional) {
        target.* = defaultValue(TargetType);
        try loader.populateValue(target.?, source);
        return;
    }

    switch (source.*) {
        .object => |*o| {
            const resolved_object = try loader.resolveObject(o.object_id);

            if (tti == .@"struct" and @hasField(TargetType, "object")) {
                target.*.object = resolved_object;
            } else if (tti == .@"union") {
                target.* = resolved_object;
            } else if (tti == .pointer and tti.pointer.size == .one) {
                if (tti.pointer.child == Object) {
                    target.* = resolved_object;
                } else {
                    target.* = try resolved_object.as(tti.pointer.child);
                }
            } else {
                return error.InvalidTargetType;
            }
        },
        .@"struct" => |*s| {
            if (tti == .@"struct") {
                try loader.populateStruct(target, s);
            } else {
                return error.InvalidTargetType;
            }
        },
        .array => |*a| {
            if (tti == .@"struct") {
                if (@hasDecl(TargetType, "Slice")) {
                    if (@typeInfo(TargetType.Slice) == .pointer) {
                        const ChildType = @typeInfo(TargetType.Slice).pointer.child;

                        try target.ensureTotalCapacityPrecise(loader.allocator, a.entries.items.len);
                        errdefer target.deinit(loader.allocator);

                        for (0..a.entries.items.len) |i| {
                            var temp_value = try defaultValue(ChildType);
                            try loader.populateValue(&temp_value, &a.entries.items[i]);
                            target.appendAssumeCapacity(temp_value);
                        }
                    } else {
                        return error.InvalidTargetType;
                    }
                } else {
                    return error.InvalidTargetType;
                }
            } else if (tti == .pointer and tti.pointer.size == .slice) {
                const ChildType = tti.pointer.child;

                const values = try loader.allocator.alloc(ChildType, a.entries.items.len);
                errdefer loader.allocator.free(values);

                for (0..a.entries.items.len) |i| {
                    var temp_value = try defaultValue(ChildType);
                    try loader.populateValue(&temp_value, &a.entries.items[i]);
                    values[i] = temp_value;
                }

                target.* = values;
            } else {
                return error.InvalidTargetType;
            }
        },
        .string => |*s| {
            if (tti == .pointer and tti.pointer.child == u8) {
                target.* = try loader.allocator.dupe(u8, s.*);
            } else {
                return error.InvalidTargetType;
            }
        },
        .int, .byte => |i| {
            if (tti == .int) {
                target.* = @intCast(i);
            } else if (tti == .@"enum") {
                target.* = @enumFromInt(i);
            } else if (tti == .bool) {
                target.* = i != 0;
            } else {
                return error.InvalidTargetType;
            }
        },
        .real => |r| {
            if (tti == .float) {
                target.* = @floatCast(r);
            } else {
                return error.InvalidTargetType;
            }
        },
        .vec12 => |v12| {
            if (tti == .@"struct" and @hasDecl(TargetType, "fromVec12")) {
                target.* = .fromVec12(v12);
            } else {
                return error.InvalidTargetType;
            }
        },
        else => {
            std.log.err("Unknown type: {s} {s}", .{ @typeName(TargetType), @tagName(source.*) });
            return error.NotImplemented;
        },
    }
}

fn resolveObject(loader: *Loader, object_id: i32) Error!*Object {
    const obj = &loader.objects.items[@intCast(object_id)];
    if (obj.* == .unresolved) {
        const other = &loader.tf.remembered_objects.items[@intCast(object_id)];
        try loader.populateObject(obj, other);
    }
    return obj;
}

fn cleanupObjects(loader: *Loader) void {
    for (loader.objects.items) |*object| {
        object.deinit(loader.allocator);
    }
    loader.objects.deinit(loader.allocator);
}

inline fn createObject(loader: *Loader, comptime T: type, tfs: *TagFileStruct) Error!*T {
    const new_obj = try loader.allocator.create(T);
    errdefer loader.allocator.destroy(new_obj);
    new_obj.* = .{};
    try populateStruct(loader, new_obj, tfs);
    return new_obj;
}

fn zigNameToHavokName(allocator: Allocator, str: []const u8) Error![]const u8 {
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

fn defaultValue(comptime T: type) Error!T {
    const ti = @typeInfo(T);
    return switch (ti) {
        .int => @intCast(0),
        .float => @floatCast(0.0),
        .bool => false,
        .@"struct" => .{},
        .pointer => undefined,
        else => return error.NoDefaultValue,
    };
}

test "loader animation" {
    const AnimationContainer = @import("AnimationContainer.zig");
    const SplineCompressedAnimation = @import("SplineCompressedAnimation.zig");

    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().openFile("resources/animation.hkt", .{ .mode = .read_only });
    defer file.close();

    const file_data = try file.readToEndAlloc(allocator, 1 << 20);
    defer allocator.free(file_data);

    const tf = try TagFile.init(allocator, file_data);
    defer tf.deinit();

    const loader = try Loader.init(allocator);
    defer loader.deinit();

    const rlc = try loader.loadFromTagFile(tf);

    const container = try rlc.getObjectByType(AnimationContainer);

    const animation = container.animations.items[0];

    const spline_animation = try animation.as(SplineCompressedAnimation);

    _ = spline_animation;
}

test "loader skeleton" {
    const AnimationContainer = @import("AnimationContainer.zig");

    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().openFile("resources/skeleton.hkt", .{ .mode = .read_only });
    defer file.close();

    const file_data = try file.readToEndAlloc(allocator, 1 << 20);
    defer allocator.free(file_data);

    const tf = try TagFile.init(allocator, file_data);
    defer tf.deinit();

    const loader = try Loader.init(allocator);
    defer loader.deinit();

    const rlc = try loader.loadFromTagFile(tf);

    const container = try rlc.getObjectByType(AnimationContainer);

    const skeleton = try container.findSkeletonByName("skeleton");
    _ = skeleton;
}
