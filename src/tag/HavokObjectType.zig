const std = @import("std");
const Allocator = std.mem.Allocator;

const HavokTagFile = @import("HavokTagFile.zig");

const HavokObjectTypeMember = @import("HavokObjectTypeMember.zig");
const HavokObjectType = @This();

allocator: Allocator,
name: []const u8,
version: u32,
parent: u32,
members: std.ArrayListUnmanaged(*HavokObjectTypeMember),

pub fn init(allocator: Allocator, htf: *HavokTagFile) !*HavokObjectType {
    const htt = try allocator.create(HavokObjectType);
    errdefer allocator.destroy(htt);

    const name = try htf.readString();
    const version = try htf.readPackedInt(u32);
    const parent = try htf.readPackedInt(u32);
    const member_count = try htf.readPackedInt(u32);

    htt.* = .{
        .allocator = allocator,
        .name = name,
        .version = version,
        .parent = parent,
        .members = .{},
    };

    try htt.members.ensureTotalCapacity(allocator, member_count);
    errdefer htt.cleanupMembers();
    for (0..member_count) |_| {
        const member = try HavokObjectTypeMember.init(allocator, htf);
        errdefer member.deinit();
        htt.members.appendAssumeCapacity(member);
    }

    return htt;
}

pub fn fake(allocator: Allocator, name: []const u8) !*HavokObjectType {
    const htt = try allocator.create(HavokObjectType);
    htt.* = .{
        .allocator = allocator,
        .name = name,
        .version = 0,
        .parent = 0,
        .members = .{},
    };
    return htt;
}

pub fn deinit(htt: *HavokObjectType) void {
    htt.cleanupMembers();
    htt.allocator.destroy(htt);
}

fn cleanupMembers(htt: *HavokObjectType) void {
    for (htt.members.items) |member| {
        member.deinit();
    }
    htt.members.deinit(htt.allocator);
}
