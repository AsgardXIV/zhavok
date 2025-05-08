const std = @import("std");
const Allocator = std.mem.Allocator;

const Skeleton = @import("Skeleton.zig");
const QsTransform = @import("vector_types.zig").QsTransform;

const SkeletonMapperData = @This();

pub const havok_name = "hkaSkeletonMapperData";

pub const PartitionMappingRange = struct {
    start_mapping_index: i32 = 0,
    num_mappings: i32 = 0,
};

pub const SimpleMapping = struct {
    bone_a: i16 = 0,
    bone_b: i16 = 0,
    a_from_b_transform: QsTransform = .{},
};

pub const ChainMapping = struct {
    start_bone_a: i16 = 0,
    end_bone_a: i16 = 0,
    start_bone_b: i16 = 0,
    end_bone_b: i16 = 0,
    start_a_from_b_transform: QsTransform = .{},
    end_a_from_b_transform: QsTransform = .{},
};

pub const MappingType = enum(u32) {
    ragdoll = 0,
    retargeting = 1,
};

skeleton_a: *Skeleton = undefined,
skeleton_b: *Skeleton = undefined,

partition_map: std.ArrayListUnmanaged(i16) = .{},
simple_mapping_partition_ranges: std.ArrayListUnmanaged(PartitionMappingRange) = .{},
chain_mapping_partition_ranges: std.ArrayListUnmanaged(PartitionMappingRange) = .{},

simple_mappings: std.ArrayListUnmanaged(SimpleMapping) = .{},
chain_mappings: std.ArrayListUnmanaged(ChainMapping) = .{},

unmapped_bones: std.ArrayListUnmanaged(i16) = .{},

extracted_motion_mapping: QsTransform = .{},

keep_unmapped_local: bool = false,

mapping_type: MappingType = .ragdoll,

pub fn deinit(skel_map_data: *SkeletonMapperData, allocator: Allocator) void {
    skel_map_data.partition_map.deinit(allocator);
    skel_map_data.simple_mapping_partition_ranges.deinit(allocator);
    skel_map_data.chain_mapping_partition_ranges.deinit(allocator);

    skel_map_data.simple_mappings.deinit(allocator);
    skel_map_data.chain_mappings.deinit(allocator);

    skel_map_data.unmapped_bones.deinit(allocator);
}
