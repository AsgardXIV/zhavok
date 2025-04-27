pub const HavokValueTypes = enum(u32) {
    empty = 0,
    byte = 1,
    int = 2,
    real = 3,
    vec4 = 4,
    vec8 = 5,
    vec12 = 6,
    vec16 = 7,
    object = 8,
    @"struct" = 9,
    string = 10,

    array = 0x10,
    array_byte = 0x11,
    array_int = 0x12,
    array_real = 0x13,
    array_vec4 = 0x14,
    array_vec8 = 0x15,
    array_vec12 = 0x16,
    array_vec16 = 0x17,
    array_object = 0x18,
    array_struct = 0x19,
    array_string = 0x1a,

    tuple = 0x20,
    tuple_byte = 0x21,
    tuple_int = 0x22,
    tuple_real = 0x23,
    tuple_vec4 = 0x24,
    tuple_vec8 = 0x25,
    tuple_vec12 = 0x26,
    tuple_vec16 = 0x27,
    tuple_object = 0x28,
    tuple_struct = 0x29,
    tuple_string = 0x2a,

    pub fn getBaseType(self: HavokValueTypes) HavokValueTypes {
        const value = @intFromEnum(self);
        const mask = 0x0F;
        const base_value = value & mask;

        return @enumFromInt(base_value);
    }
};
