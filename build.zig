const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("deep_hash_map", .{
        .source_file = .{ .path = "deep_hash_map.zig" },
    });
}
