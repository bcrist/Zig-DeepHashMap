const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("deep_hash_map", .{
        .root_source_file = b.path("deep_hash_map.zig"),
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("deep_hash_map.zig"),
            .target = b.standardTargetOptions(.{}),
            .optimize = b.standardOptimizeOption(.{}),
        }),
    });
    b.step("test", "Run all tests").dependOn(&b.addRunArtifact(tests).step);
}
