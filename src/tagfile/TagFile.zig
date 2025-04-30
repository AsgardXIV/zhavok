const std = @import("std");
const Allocator = std.mem.Allocator;

const FixedBufferStream = std.io.FixedBufferStream([]u8);

const TagFileSection = @import("tag_file_section.zig").TagFileSection;
const TagFileValueType = @import("tag_file_value_type.zig").TagFileValueType;
const TagFileValue = @import("tag_file_value.zig").TagFileValue;
const TagFileMemberInfo = @import("TagFileMemberInfo.zig");
const TagFileTypeInfo = @import("TagFileTypeInfo.zig");
const TagFileStruct = @import("TagFileStruct.zig");

const TagFile = @This();

pub const Error = error{
    OutOfMemory,
    ReadError,
    InvalidMagic,
    InvalidSection,
    UnsupportedVersion,
    InvalidStruct,
    IndexNotFound,
    InvalidVector,
    CouldNotResolveObject,
};

const expected_magic_1: u32 = 0xCAB00D1E;
const expected_magic_2: u32 = 0xD011FACE;

allocator: Allocator,

buffer: []u8,
fbs: FixedBufferStream,
reader: std.io.AnyReader,

havok_version: ?[]const u8,
remembered_strings: std.ArrayListUnmanaged([]const u8),
remembered_types: std.ArrayListUnmanaged(TagFileTypeInfo),
remembered_objects: std.ArrayListUnmanaged(TagFileStruct),

pub fn init(
    allocator: Allocator,
    buffer: []const u8,
) Error!*TagFile {
    var tf: *TagFile = try allocator.create(TagFile);
    errdefer allocator.destroy(tf);

    const duped_buffer = try allocator.dupe(u8, buffer);
    errdefer allocator.free(duped_buffer);

    tf.* = .{
        .allocator = allocator,
        .buffer = duped_buffer,
        .fbs = undefined,
        .reader = undefined,
        .havok_version = null,
        .remembered_strings = .{},
        .remembered_types = .{},
        .remembered_objects = .{},
    };
    tf.fbs = std.io.fixedBufferStream(tf.buffer);
    tf.reader = tf.fbs.reader().any();

    try tf.parse();

    return tf;
}

pub fn deinit(tf: *TagFile) void {
    tf.cleanupObjects();
    tf.cleanupTypes();
    tf.cleanupStrings();

    tf.allocator.free(tf.buffer);

    tf.allocator.destroy(tf);
}

fn parse(tf: *TagFile) Error!void {
    // First we verify the magic numbers
    const magic_1 = tf.reader.readInt(u32, .little) catch return Error.ReadError;
    const magic_2 = tf.reader.readInt(u32, .little) catch return Error.ReadError;

    if (magic_1 != 0xCAB00D1E or magic_2 != 0xD011FACE) {
        return Error.InvalidMagic;
    }

    // If we error out, we just cleanup so we don't leak
    errdefer {
        tf.cleanupObjects();
        tf.cleanupTypes();
        tf.cleanupStrings();
    }

    // Now we can read the sections
    section_loop: while (true) {
        const section = try tf.readPackedInt(TagFileSection);

        switch (section) {
            .file_info => {
                try tf.populateDefaultStrings();
                try tf.populateDefaultTypes();
                try tf.populateDefaultObjects();
                try tf.readFileInfo();
            },
            .type_info => {
                const info = try tf.readTypeInfo();
                try tf.remembered_types.append(tf.allocator, info);
            },
            .object_remember => {
                const object = try tf.readStruct(null);
                try tf.remembered_objects.append(tf.allocator, object);
            },
            .file_end => {
                break :section_loop;
            },
            else => {
                return Error.InvalidSection;
            },
        }
    }

    for (tf.remembered_objects.items) |*object| {
        try tf.populateStructObjectReferences(object);
    }
}

pub fn getRootObject(tf: *TagFile) Error!TagFileStruct {
    if (tf.remembered_objects.items.len <= 2) {
        return Error.InvalidStruct;
    }

    return tf.remembered_objects.items[1];
}

fn readStruct(tf: *TagFile, class_index: ?i32) Error!TagFileStruct {
    // Read the class index if needed
    const resolved_class_index = if (class_index) |ci| ci else tf.readPackedInt(i32) catch return Error.InvalidStruct;
    const type_info = &tf.remembered_types.items[@intCast(resolved_class_index)];

    var tfs = TagFileStruct{
        .type_info = type_info,
        .fields = .{},
    };

    // Calculate the members
    const member_count = tf.calculateTotalMembers(resolved_class_index);

    // Determine which members are present
    const member_present = try tf.allocator.alloc(bool, member_count);
    defer tf.allocator.free(member_present);
    try tf.readBitfield(member_present);

    // Populate the members
    var member_index: usize = 0;
    try tf.parseStructMembers(&tfs, resolved_class_index, member_present, &member_index);

    return tfs;
}

fn parseStructMembers(tf: *TagFile, tfs: *TagFileStruct, class_index: i32, bitmap: []bool, member_index: *usize) Error!void {
    const type_info = &tf.remembered_types.items[@intCast(class_index)];

    // Recurse into the parent type if needed
    if (type_info.parent_type_index != 0) {
        try tf.parseStructMembers(tfs, type_info.parent_type_index, bitmap, member_index);
    }

    // Now we process each member
    for (type_info.members.items) |*member_info| {
        var value: TagFileValue = undefined;

        // We only need to parse the member if it is present
        if (bitmap[member_index.*]) {
            try tf.parseField(&value, member_info);

            try tfs.fields.put(tf.allocator, member_index.*, value);
        }

        // Keep track of the overall member index
        member_index.* += 1;
    }
}

fn parseField(tf: *TagFile, tfv: *TagFileValue, member_info: *TagFileMemberInfo) Error!void {
    if (member_info.type.isSizedContainer()) {
        const size: usize = if (member_info.type.isTuple()) @intCast(member_info.tuple_size.?) else try tf.readPackedInt(usize);
        var array: TagFileValue.Array = .{
            .entries = .{},
        };
        errdefer tf.cleanupArray(&array);
        try array.entries.ensureTotalCapacityPrecise(tf.allocator, size);

        try tf.parseArray(tfv, member_info, &array);

        tfv.* = TagFileValue{
            .array = array,
        };
    } else {
        try tf.parseFieldValue(tfv, member_info.type.getElementType(), member_info.class_name, -1);
    }
}

fn parseFieldValue(tf: *TagFile, tfv: *TagFileValue, value_type: TagFileValueType, class_name: ?[]const u8, array_prefix: i32) Error!void {
    switch (value_type) {
        .byte => {
            tfv.* = TagFileValue{
                .byte = tf.reader.readByte() catch return Error.ReadError,
            };
        },
        .int => {
            tfv.* = TagFileValue{
                .int = try tf.readPackedInt(i32),
            };
        },
        .real => {
            const raw = tf.reader.readInt(u32, .little) catch return Error.ReadError;
            tfv.* = TagFileValue{
                .real = @bitCast(raw),
            };
        },
        .vec4 => {
            const final_prefix: usize = if (array_prefix < 0) 4 else @intCast(array_prefix);
            if (final_prefix < 1 or final_prefix > 4) {
                @branchHint(.unlikely);
                return Error.InvalidVector;
            }

            var vec_components: [4]f32 = @splat(0.0);
            for (0..final_prefix) |i| {
                const raw = tf.reader.readInt(u32, .little) catch return Error.ReadError;
                vec_components[i] = @bitCast(raw);
            }

            tfv.* = .{
                .vec4 = .{
                    .x = vec_components[0],
                    .y = vec_components[1],
                    .z = vec_components[2],
                    .w = vec_components[3],
                },
            };
        },
        .vec8 => {
            tfv.* = TagFileValue{
                .vec8 = tf.reader.readStruct(TagFileValue.Vec8) catch return Error.ReadError,
            };
        },
        .vec12 => {
            tfv.* = TagFileValue{
                .vec12 = tf.reader.readStruct(TagFileValue.Vec12) catch return Error.ReadError,
            };
        },
        .vec16 => {
            tfv.* = TagFileValue{
                .vec16 = tf.reader.readStruct(TagFileValue.Vec16) catch return Error.ReadError,
            };
        },
        .object => {
            tfv.* = TagFileValue{
                .object = .{
                    .object_id = try tf.readPackedInt(i32),
                    .resolved = undefined,
                },
            };
        },
        .@"struct" => {
            if (class_name) |name| {
                const class_index = try tf.getClassIndexFromName(name);
                const value = try tf.readStruct(class_index);
                tfv.* = .{
                    .@"struct" = value,
                };
            } else {
                return Error.InvalidStruct;
            }
        },
        .string => {
            tfv.* = TagFileValue{
                .string = try tf.readString(),
            };
        },
        else => {
            @breakpoint();
            return Error.ReadError;
        },
    }
}

fn parseArray(tf: *TagFile, tfv: *TagFileValue, member_info: *TagFileMemberInfo, array: *TagFileValue.Array) Error!void {
    const element_type = member_info.type.getElementType();

    const prefix = switch (element_type) {
        .int, .vec4 => try tf.readPackedInt(i32),
        else => -1,
    };

    switch (element_type) {
        .@"struct" => try tf.parseStructArray(tfv, member_info, array),
        else => {
            for (0..array.entries.capacity) |_| {
                var result: TagFileValue = undefined;
                try tf.parseFieldValue(&result, member_info.type.getElementType(), member_info.class_name, prefix);
                try array.entries.append(tf.allocator, result);
            }
        },
    }
}

fn parseStructArray(tf: *TagFile, tfv: *TagFileValue, member_info: *TagFileMemberInfo, array: *TagFileValue.Array) Error!void {
    const class_index = if (member_info.type == .array_struct and member_info.class_name == null) try tf.readPackedInt(i32) else tf.getClassIndexFromName(member_info.class_name.?) catch 0;
    if (class_index == 0) {
        return Error.IndexNotFound;
    }

    const member_count = tf.calculateTotalMembers(class_index);

    const member_present = try tf.allocator.alloc(bool, member_count);
    defer tf.allocator.free(member_present);
    try tf.readBitfield(member_present);

    const type_info = &tf.remembered_types.items[@intCast(class_index)];

    for (0..array.entries.capacity) |_| {
        array.entries.appendAssumeCapacity(.{
            .@"struct" = .{
                .type_info = type_info,
                .fields = .{},
            },
        });
    }

    for (0..member_count) |index| {
        if (member_present[index] == false) {
            continue;
        }

        const target_member_info_req = tf.calculateMemberInfoByIndex(type_info, index, null);
        if (target_member_info_req == null) {
            return Error.IndexNotFound;
        }
        const target_member_info = target_member_info_req.?;

        var tmp_array: TagFileValue.Array = .{
            .entries = .{},
        };
        defer tmp_array.entries.deinit(tf.allocator);
        try tmp_array.entries.ensureTotalCapacityPrecise(tf.allocator, array.entries.capacity);

        try tf.parseArray(tfv, target_member_info, &tmp_array);

        for (tmp_array.entries.items, 0..) |*tmp_entry, i| {
            try array.entries.items[i].@"struct".fields.put(tf.allocator, index, tmp_entry.*);
        }
    }
}

fn readFileInfo(tf: *TagFile) Error!void {
    const version = try tf.readPackedInt(i32);

    if (version != 3 and version != 4) {
        return Error.UnsupportedVersion;
    }

    if (version >= 4) {
        tf.havok_version = try tf.readString();
    }
}

fn readTypeInfo(tf: *TagFile) Error!TagFileTypeInfo {
    const name = try tf.readString();
    const unk3 = try tf.readPackedInt(i32);
    const parent_type_index = try tf.readPackedInt(i32);
    const member_count = try tf.readPackedInt(usize);

    var members = std.ArrayListUnmanaged(TagFileMemberInfo){};
    errdefer members.deinit(tf.allocator);
    try members.ensureTotalCapacityPrecise(tf.allocator, member_count);

    for (0..member_count) |_| {
        const member_info = try tf.readMemberInfo();
        members.appendAssumeCapacity(member_info);
    }

    return .{
        .name = name,
        ._unk3 = unk3,
        .parent_type_index = parent_type_index,
        .members = members,
    };
}

fn readMemberInfo(tf: *TagFile) Error!TagFileMemberInfo {
    const name = try tf.readString();
    const tag_type = try tf.readPackedInt(TagFileValueType);

    const tuple_size = if (tag_type.isTuple()) try tf.readPackedInt(i32) else null;

    const element_type = tag_type.getElementType();
    const class_name = if (element_type == .@"struct" or element_type == .object) try tf.readString() else null;

    return .{
        .name = name,
        .type = tag_type,
        .tuple_size = tuple_size,
        .class_name = class_name,
    };
}

fn readString(tf: *TagFile) Error![]const u8 {
    const length = try tf.readPackedInt(i32);

    if (length < 0) {
        const idx: u32 = @intCast(-length);
        return tf.remembered_strings.items[idx];
    }

    const str = try tf.allocator.alloc(u8, @intCast(length));
    errdefer tf.allocator.free(str);
    _ = tf.reader.readAll(str) catch return Error.ReadError;

    try tf.remembered_strings.append(tf.allocator, str);

    return str;
}

fn readPackedInt(tf: *TagFile, comptime ReadAs: type) Error!ReadAs {
    const reader = &tf.reader;

    var byte = reader.readByte() catch return Error.ReadError;
    var result: i32 = ((byte & 0x7e) >> 1);
    const is_negative = byte & 0x1 != 0;
    var shift: u32 = 6;

    while (byte & 0x80 != 0) {
        byte = reader.readByte() catch return Error.ReadError;
        result |= std.math.shl(i32, byte & 0x7f, shift);
        shift += 7;
    }

    if (is_negative) {
        result = -result;
    }

    return switch (@typeInfo(ReadAs)) {
        .int => @intCast(result),
        .@"enum" => @enumFromInt(result),
        else => Error.ReadError,
    };
}

fn readBitfield(tf: *TagFile, bits: []bool) Error!void {
    const bytes_needed = (bits.len + 7) / 8;
    const bytes = try tf.allocator.alloc(u8, bytes_needed);
    defer tf.allocator.free(bytes);

    _ = tf.reader.readAll(bytes) catch return Error.ReadError;

    for (0..bits.len) |i| {
        bits[i] = (bytes[i / 8] & (@as(u32, 1) << @as(u3, @intCast(i % 8)))) != 0;
    }
}

fn populateStructObjectReferences(tf: *TagFile, object: *TagFileStruct) Error!void {
    var iter = object.fields.iterator();
    while (iter.next()) |field| {
        if (field.value_ptr.* == .object) {
            const object_id = field.value_ptr.object.object_id;

            if (object_id < 0) {
                return Error.CouldNotResolveObject;
            }
            if (tf.remembered_objects.items.len <= object_id) {
                return Error.CouldNotResolveObject;
            }

            const resolved_object = &tf.remembered_objects.items[@intCast(object_id)];
            field.value_ptr.object.resolved = resolved_object;
        } else if (field.value_ptr.* == .@"struct") {
            try tf.populateStructObjectReferences(&field.value_ptr.@"struct");
        } else if (field.value_ptr.* == .array) {
            try tf.populateArrayObjectReferences(&field.value_ptr.array);
        }
    }
}

fn populateArrayObjectReferences(tf: *TagFile, array: *TagFileValue.Array) Error!void {
    for (array.entries.items) |*entry| {
        if (entry.* == .object) {
            const object_id = entry.*.object.object_id;

            if (object_id < 0) {
                return Error.CouldNotResolveObject;
            }
            if (tf.remembered_objects.items.len <= object_id) {
                return Error.CouldNotResolveObject;
            }

            const resolved_object = &tf.remembered_objects.items[@intCast(object_id)];
            entry.*.object.resolved = resolved_object;
        } else if (entry.* == .@"struct") {
            try tf.populateStructObjectReferences(&entry.*.@"struct");
        } else if (entry.* == .array) {
            try tf.populateArrayObjectReferences(&entry.*.array);
        }
    }
}

fn calculateTotalMembers(tf: *TagFile, class_index: i32) usize {
    var count: usize = 0;
    var current_index = class_index;

    while (current_index != 0) {
        const type_info = &tf.remembered_types.items[@intCast(current_index)];
        count += type_info.members.items.len;
        current_index = type_info.parent_type_index;
    }

    return count;
}

fn calculateMemberInfoByIndex(tf: *TagFile, type_info: *TagFileTypeInfo, target_index: usize, current_index: ?*usize) ?*TagFileMemberInfo {
    var storage: usize = 0;

    const internal_index: *usize = if (current_index) |ci| ci else &storage;

    if (type_info.parent_type_index != 0) {
        const result = tf.calculateMemberInfoByIndex(&tf.remembered_types.items[@intCast(type_info.parent_type_index)], target_index, internal_index);
        if (result) |ret| {
            return ret;
        }
    }

    if (target_index - internal_index.* < type_info.members.items.len) {
        return &type_info.members.items[target_index - internal_index.*];
    } else {
        internal_index.* += type_info.members.items.len;
    }

    return null;
}

fn getClassIndexFromName(tf: *TagFile, name: []const u8) Error!i32 {
    for (tf.remembered_types.items, 0..) |*type_info, i| {
        if (std.mem.eql(u8, type_info.name, name)) {
            return @intCast(i);
        }
    }

    return Error.IndexNotFound;
}

fn populateDefaultStrings(tf: *TagFile) Error!void {
    tf.cleanupStrings();

    try tf.remembered_strings.append(tf.allocator, "");
    try tf.remembered_strings.append(tf.allocator, "");
}

fn cleanupStrings(tf: *TagFile) void {
    for (tf.remembered_strings.items) |str| {
        tf.allocator.free(str);
    }
    tf.remembered_strings.deinit(tf.allocator);
    tf.remembered_strings = .{};
}

fn populateDefaultTypes(tf: *TagFile) Error!void {
    tf.cleanupTypes();

    var tfi = TagFileTypeInfo{
        .name = "BuiltinVoidType",
        ._unk3 = 0,
        .parent_type_index = 0,
        .members = .{},
    };

    const tfm = TagFileMemberInfo{
        .name = "void",
        .type = TagFileValueType.void,
        .tuple_size = null,
        .class_name = null,
    };
    try tfi.members.append(tf.allocator, tfm);

    try tf.remembered_types.append(tf.allocator, tfi);
}

fn cleanupTypes(tf: *TagFile) void {
    for (tf.remembered_types.items) |*type_info| {
        type_info.members.deinit(tf.allocator);
    }
    tf.remembered_types.deinit(tf.allocator);
    tf.remembered_types = .{};
}

fn populateDefaultObjects(tf: *TagFile) Error!void {
    tf.cleanupObjects();

    try tf.remembered_objects.append(tf.allocator, .{
        .type_info = &tf.remembered_types.items[0],
        .fields = .{},
    });
}

fn cleanupObjects(tf: *TagFile) void {
    for (tf.remembered_objects.items) |*object| {
        tf.cleanupStruct(object);
    }
    tf.remembered_objects.deinit(tf.allocator);
    tf.remembered_objects = .{};
}

fn cleanupStruct(tf: *TagFile, object: *TagFileStruct) void {
    var it = object.fields.iterator();
    while (it.next()) |field| {
        if (field.value_ptr.* == .@"struct") {
            tf.cleanupStruct(&field.value_ptr.@"struct");
        } else if (field.value_ptr.* == .array) {
            tf.cleanupArray(&field.value_ptr.array);
        }
    }
    object.fields.deinit(tf.allocator);
}

fn cleanupArray(tf: *TagFile, array: *TagFileValue.Array) void {
    for (array.entries.items) |*entry| {
        if (entry.* == .@"struct") {
            tf.cleanupStruct(&entry.*.@"struct");
        } else if (entry.* == .array) {
            tf.cleanupArray(&entry.*.array);
        }
    }
    array.entries.deinit(tf.allocator);
}

test "test skeleton" {
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().openFile("resources/skeleton.tag", .{ .mode = .read_only });
    defer file.close();

    const file_data = try file.readToEndAlloc(allocator, 1 << 20);
    defer allocator.free(file_data);

    const tf = try TagFile.init(allocator, file_data);
    defer tf.deinit();

    const root = try tf.getRootObject();

    try std.testing.expectEqualStrings("hkRootLevelContainer", root.type_info.name);
}

test "test animation" {
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().openFile("resources/animation.tag", .{ .mode = .read_only });
    defer file.close();

    const file_data = try file.readToEndAlloc(allocator, 1 << 20);
    defer allocator.free(file_data);

    const tf = try TagFile.init(allocator, file_data);
    defer tf.deinit();

    const root = try tf.getRootObject();

    try std.testing.expectEqualStrings("hkRootLevelContainer", root.type_info.name);
}
