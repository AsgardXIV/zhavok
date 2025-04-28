const std = @import("std");
const Allocator = std.mem.Allocator;

const FixedBufferStream = std.io.FixedBufferStream([]u8);

const TagFileTypeInfo = @import("TagFileTypeInfo.zig");
const TagFileStruct = @import("TagFileStruct.zig");

const TagFile = @This();

allocator: Allocator,

buffer: []u8,
fbs: FixedBufferStream,
reader: std.io.AnyReader,

havok_version: ?[]const u8,
remembered_strings: std.ArrayListUnmanaged([]const u8),
remembered_types: std.ArrayListUnmanaged(TagFileTypeInfo),
remembered_objects: std.ArrayListUnmanaged(TagFileStruct),

objects: std.ArrayListUnmanaged(TagFileStruct),

pub fn init(
    allocator: Allocator,
    buffer: []const u8,
) !*TagFile {
    var htf: *TagFile = try allocator.create(TagFile);
    errdefer allocator.destroy(htf);

    const duped_buffer = try allocator.dupe(u8, buffer);
    errdefer allocator.free(duped_buffer);

    htf.* = .{
        .allocator = allocator,
        .buffer = duped_buffer,
        .fbs = undefined,
        .reader = undefined,
        .havok_version = null,
        .remembered_strings = .{},
        .remembered_types = .{},
        .remembered_objects = .{},
        .objects = .{},
    };
    htf.fbs = std.io.fixedBufferStream(htf.buffer);
    htf.reader = htf.fbs.reader().any();

    try htf.parse();

    return htf;
}

pub fn deinit(htf: *TagFile) void {
    htf.cleanupObjects();
    htf.cleanupTypes();
    htf.cleanupStrings();

    htf.allocator.free(htf.buffer);

    htf.allocator.destroy(htf);
}

fn parse(htf: *TagFile) !void {
    errdefer {
        htf.cleanupObjects();
        htf.cleanupTypes();
        htf.cleanupStrings();
    }

    // Verify magic
    const magic_1 = try htf.reader.readInt(u32, .little);
    const magic_2 = try htf.reader.readInt(u32, .little);

    if (magic_1 != 0xCAB00D1E or magic_2 != 0xD011FACE) {
        return error.InvalidMagic;
    }

    // Read the sections
    while (true) section_loop: {
        const section_raw = try htf.readPackedInt(i32);
        const section: TagFileSections = @enumFromInt(section_raw);

        switch (section) {
            .file_info => {
                try htf.populateDefaultStrings();
                try htf.populateDefaultTypes();

                const version = try htf.readPackedInt(i32);

                if (version != 3 and version != 4) {
                    return error.UnsupportedVersion;
                }

                if (version == 4) {
                    htf.havok_version = try htf.readString();
                }
            },
            .type_info => {
                var type_info = try TagFileTypeInfo.createFromStream(htf.allocator, htf);
                errdefer type_info.free(htf.allocator);

                try htf.remembered_types.append(htf.allocator, type_info);
            },
            .object_remember => {
                var object = try TagFileStruct.createFromStream(htf.allocator, htf, 0);
                errdefer object.free(htf.allocator);

                try htf.remembered_objects.append(htf.allocator, object);
                try htf.objects.append(htf.allocator, object);
            },
            .file_end => break :section_loop,
            else => return error.InvalidSection,
        }
    }
}

pub fn readString(htf: *TagFile) ![]const u8 {
    const length = try htf.readPackedInt(i32);

    if (length < 0) {
        const idx: u32 = @intCast(-length);
        return htf.remembered_strings.items[idx];
    }

    const str = try htf.allocator.alloc(u8, @intCast(length));
    errdefer htf.allocator.free(str);
    _ = try htf.reader.readAll(str);

    try htf.remembered_strings.append(htf.allocator, str);

    return str;
}

pub fn readPackedInt(htf: *TagFile, comptime ReadAs: type) !ReadAs {
    const reader = &htf.reader;

    var byte = try reader.readByte();
    var result: i32 = ((byte & 0x7f) >> 1);
    const is_negative = byte & 0x1 != 0;
    var shift: u32 = 6;

    while (byte & 0x80 != 0) {
        byte = try reader.readByte();
        result |= std.math.shl(i32, byte & 0x7f, shift);
        shift += 7;
    }

    if (is_negative) {
        result = -result;
    }

    return @intCast(result);
}

pub fn readBitfield(htf: *TagFile, bits: []bool) !void {
    var bit_reader = std.io.bitReader(.little, htf.reader);

    for (0..bits.len) |i| {
        bits[i] = try bit_reader.readBitsNoEof(u1, 1) != 0;
    }
}

pub fn findTypeIndex(htf: *TagFile, name: []const u8) !i32 {
    for (htf.remembered_types.items, 0..) |*type_info, i| {
        if (std.mem.eql(u8, type_info.name, name)) {
            return @intCast(i);
        }
    }

    return error.TypeNotFound;
}

fn populateDefaultStrings(htf: *TagFile) !void {
    htf.cleanupStrings();

    try htf.remembered_strings.append(htf.allocator, "");
    try htf.remembered_strings.append(htf.allocator, "");
}

fn cleanupStrings(htf: *TagFile) void {
    for (htf.remembered_strings.items) |str| {
        htf.allocator.free(str);
    }
    htf.remembered_strings.deinit(htf.allocator);
    htf.remembered_strings = .{};
}

fn populateDefaultTypes(htf: *TagFile) !void {
    htf.cleanupTypes();

    var void_type = try TagFileTypeInfo.voidType(htf.allocator);
    errdefer void_type.free(htf.allocator);
    try htf.remembered_types.append(htf.allocator, void_type);
}

fn cleanupTypes(htf: *TagFile) void {
    for (htf.remembered_types.items) |*type_info| {
        type_info.free(htf.allocator);
    }
    htf.remembered_types.deinit(htf.allocator);
    htf.remembered_types = .{};
}

fn cleanupObjects(htf: *TagFile) void {
    htf.remembered_objects.deinit(htf.allocator);
    htf.remembered_objects = .{};

    for (htf.objects.items) |*object| {
        object.free(htf.allocator);
    }
    htf.objects.deinit(htf.allocator);
    htf.objects = .{};
}

const TagFileSections = enum(i32) {
    none = 0,
    file_info = 1,
    type_info = 2,
    object = 3,
    object_remember = 4,
    object_backref = 5,
    object_null = 6,
    file_end = 7,
};

test "test.tag" {
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().openFile("resources/test.tag", .{ .mode = .read_only });
    defer file.close();

    const file_data = try file.readToEndAlloc(allocator, 1 << 20);
    defer allocator.free(file_data);

    const htf = try TagFile.init(allocator, file_data);
    defer htf.deinit();
}
