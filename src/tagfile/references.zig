const TagFileStruct = @import("TagFileStruct.zig");
const TagFileTypeInfo = @import("TagFileTypeInfo.zig");
const TagFile = @import("TagFile.zig");

pub const ObjectReference = struct {
    object_id: i32,
    resolved: *TagFileStruct = undefined,

    pub fn resolve(self: *ObjectReference, tf: *TagFile) !void {
        if (self.object_id < 0) {
            return error.CouldNotResolveObject;
        }

        if (tf.remembered_objects.items.len <= self.object_id) {
            return error.CouldNotResolveObject;
        }

        self.resolved = &tf.remembered_objects.items[@intCast(self.object_id)];
    }
};

pub const TypeInfoReference = struct {
    type_id: i32,
    resolved: *TagFileTypeInfo = undefined,

    pub fn resolve(self: *TypeInfoReference, tf: *TagFile) !void {
        if (self.type_id < 0) {
            return error.CouldNotResolveType;
        }

        if (tf.remembered_types.items.len <= self.type_id) {
            return error.CouldNotResolveType;
        }

        self.resolved = &tf.remembered_types.items[@intCast(self.type_id)];
    }
};
