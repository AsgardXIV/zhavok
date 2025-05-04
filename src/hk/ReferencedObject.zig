const BaseObject = @import("BaseObject.zig");

pub const havok_name = "hkReferencedObject";

base: BaseObject = .{},
mem_size_and_ref_count: u32 = 0,
