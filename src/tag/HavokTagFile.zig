const std = @import("std");
const Allocator = std.mem.Allocator;

const FixedBufferStream = std.io.FixedBufferStream([]u8);

const HavokObject = @import("HavokObject.zig");
const HavokObjectType = @import("HavokObjectType.zig");

const HavokTagFile = @This();

allocator: Allocator,

buffer: []u8,
fbs: FixedBufferStream,
reader: std.io.AnyReader,

remembered_strings: std.ArrayListUnmanaged([]const u8),
remembered_types: std.ArrayListUnmanaged(*HavokObjectType),
remembered_objects: std.ArrayListUnmanaged(*HavokObject),

objects: std.ArrayListUnmanaged(*HavokObject),

pub fn init(
    allocator: Allocator,
    buffer: []const u8,
) !*HavokTagFile {
    var htf: *HavokTagFile = try allocator.create(HavokTagFile);
    errdefer allocator.destroy(htf);

    const duped_buffer = try allocator.dupe(u8, buffer);
    errdefer allocator.free(duped_buffer);

    htf.* = .{
        .allocator = allocator,
        .buffer = duped_buffer,
        .fbs = undefined,
        .reader = undefined,
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

pub fn deinit(htf: *HavokTagFile) void {
    htf.cleanupStrings();
    htf.cleanupTypes();

    htf.allocator.destroy(htf);
}

fn parse(htf: *HavokTagFile) !void {
    errdefer {
        htf.cleanupStrings();
        htf.cleanupTypes();
        htf.cleanupObjects();
    }

    // Setup some default values
    try htf.remembered_strings.append(htf.allocator, "string");
    try htf.remembered_strings.append(htf.allocator, "");

    try htf.remembered_types.append(htf.allocator, try HavokObjectType.fake(htf.allocator, "object"));

    // Verify magic
    const magic_1 = try htf.reader.readInt(u32, .little);
    const magic_2 = try htf.reader.readInt(u32, .little);

    if (magic_1 != 0xCAB00D1E or magic_2 != 0xD011FACE) {
        return error.InvalidMagic;
    }

    // Start parsing
    while (true) loop: {
        const raw_tag_type = try htf.readPackedInt(i32);
        const tag_type: HavokTagOp = @enumFromInt(raw_tag_type);

        switch (tag_type) {
            .file_info => {
                const version = try htf.readPackedInt(u32);
                _ = version;
            },
            .type => {
                const havok_type = try HavokObjectType.init(htf.allocator, htf);
                errdefer havok_type.deinit();
                try htf.remembered_types.append(htf.allocator, havok_type);
            },
            .object, .object_remember => {
                const havok_object = try HavokObject.init(htf.allocator, htf);
                errdefer havok_object.deinit();

                try htf.objects.append(htf.allocator, havok_object);

                if (tag_type == .object_remember) {
                    try htf.remembered_objects.append(htf.allocator, havok_object);
                }
            },
            .file_end => break :loop,
            else => {
                @breakpoint();
            },
        }
    }
}

pub fn readString(htf: *HavokTagFile) ![]const u8 {
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

pub fn readPackedInt(htf: *HavokTagFile, comptime ReadAs: type) !ReadAs {
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

pub fn readBitfield(htf: *HavokTagFile, bits: []bool) !void {
    var bit_reader = std.io.bitReader(.little, htf.reader);

    for (0..bits.len) |i| {
        bits[i] = try bit_reader.readBitsNoEof(u1, 1) != 0;
    }
}

fn cleanupStrings(htf: *HavokTagFile) void {
    for (htf.remembered_strings.items) |str| {
        htf.allocator.free(str);
    }
    htf.remembered_strings.deinit(htf.allocator);
}

fn cleanupTypes(htf: *HavokTagFile) void {
    for (htf.remembered_types.items) |tag_type| {
        tag_type.deinit();
    }
    htf.remembered_types.deinit(htf.allocator);
}

fn cleanupObjects(htf: *HavokTagFile) void {
    for (htf.objects.items) |object| {
        object.deinit();
    }
    htf.objects.deinit(htf.allocator);

    htf.remembered_objects.deinit(htf.allocator);
}

const HavokTagOp = enum(i8) {
    eof = -1,
    invalid = 0,
    file_info = 1,
    type = 2,
    object = 3,
    object_remember = 4,
    back_ref = 5,
    object_null = 6,
    file_end = 7,
};

test "test.tag" {
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().openFile("resources/test.tag", .{ .mode = .read_only });
    defer file.close();

    const file_data = try file.readToEndAlloc(allocator, 1 << 20);
    defer allocator.free(file_data);

    const htf = try HavokTagFile.init(allocator, file_data);
    defer htf.deinit();
}
