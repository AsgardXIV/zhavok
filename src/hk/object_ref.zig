const Object = @import("object.zig").Object;

pub fn ObjectRef(comptime T: type) type {
    return struct {
        object: *Object = undefined,

        pub fn get(self: *T) *T {
            return @alignCast(@ptrCast(self.object.getPtr()));
        }
    };
}
