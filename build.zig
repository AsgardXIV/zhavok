const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Lib
    const zhavok_lib_mod = b.addModule("zhavok", .{
        .root_source_file = b.path("src/zhavok.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zhavok_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zhavok",
        .root_module = zhavok_lib_mod,
    });

    b.installArtifact(zhavok_lib);

    // Tests
    const zhavok_unit_tests = b.addTest(.{
        .name = "zhavok_unit_tests",
        .root_module = zhavok_lib_mod,
    });

    const run_zhavok_unit_tests = b.addRunArtifact(zhavok_unit_tests);

    const zhavok_test_step = b.step("test", "Run unit tests");
    zhavok_test_step.dependOn(&run_zhavok_unit_tests.step);

    b.installArtifact(zhavok_unit_tests);

    // Docs
    const zhavok_docs = b.addInstallDirectory(.{
        .source_dir = zhavok_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const zhavok_docs_step = b.step("docs", "Install docs");
    zhavok_docs_step.dependOn(&zhavok_docs.step);
}
