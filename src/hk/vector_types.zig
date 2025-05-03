const TagFileValue = @import("../tagfile/tag_file_value.zig").TagFileValue;

pub const Vector4 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    w: f32 = 0.0,

    pub fn fromVec4(val: TagFileValue.Vec4) Vector4 {
        return Vector4{
            .x = val.x,
            .y = val.y,
            .z = val.z,
            .w = val.w,
        };
    }
};

pub const Quaternion = struct {
    vec: Vector4 = .{},

    pub fn fromVec4(val: TagFileValue.Vec4) Quaternion {
        return Quaternion{
            .vec = .fromVec4(val),
        };
    }
};

pub const QsTransform = struct {
    translation: Vector4 = .{},
    rotation: Quaternion = .{},
    scale: Vector4 = .{},

    pub fn fromVec12(val: TagFileValue.Vec12) QsTransform {
        return QsTransform{
            .translation = .fromVec4(val.v[0]),
            .rotation = .fromVec4(val.v[1]),
            .scale = .fromVec4(val.v[2]),
        };
    }
};
