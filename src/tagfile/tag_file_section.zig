pub const TagFileSection = enum(i32) {
    none = 0,
    file_info = 1,
    type_info = 2,
    object = 3,
    object_remember = 4,
    object_backref = 5,
    object_null = 6,
    file_end = 7,
};
