pub const TagFileValueType = enum(u32) {
    void = 0x0,
    byte = 0x1,
    int = 0x2,
    real = 0x3,
    vec4 = 0x4,
    vec8 = 0x5,
    vec12 = 0x6,
    vec16 = 0x7,
    object = 0x8,
    @"struct" = 0x9,
    string = 0xA,

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

    _,

    pub fn getContainerType(self: TagFileValueType) TagFileValueType {
        const value = @intFromEnum(self);
        const mask = 0xF0;
        const masked_value = value & mask;

        return @enumFromInt(masked_value);
    }

    pub fn getElementType(self: TagFileValueType) TagFileValueType {
        const value = @intFromEnum(self);
        const mask = 0x0F;
        const masked_value = value & mask;

        return @enumFromInt(masked_value);
    }

    pub fn isSizedContainer(self: TagFileValueType) bool {
        return self.isArray() or self.isTuple();
    }

    pub fn isArray(self: TagFileValueType) bool {
        return self.getContainerType() == TagFileValueType.array;
    }

    pub fn isTuple(self: TagFileValueType) bool {
        return self.getContainerType() == TagFileValueType.tuple;
    }
};
