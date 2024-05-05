const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("deep_hash_map", .{
        .root_source_file = .{ .path = "deep_hash_map.zig" },
    });

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "deep_hash_map.zig"},
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests.step);
}
