pub fn ShallowAutoHashMap(comptime K: type, comptime V: type) type {
    return std.HashMap(K, V, StrategyContext(K, .Shallow), std.hash_map.default_max_load_percentage);
}

pub fn ShallowAutoHashMapUnmanaged(comptime K: type, comptime V: type) type {
    return std.HashMapUnmanaged(K, V, StrategyContext(K, .Shallow), std.hash_map.default_max_load_percentage);
}

pub fn DeepAutoHashMap(comptime K: type, comptime V: type) type {
    return std.HashMap(K, V, StrategyContext(K, .Deep), std.hash_map.default_max_load_percentage);
}

pub fn DeepAutoHashMapUnmanaged(comptime K: type, comptime V: type) type {
    return std.HashMapUnmanaged(K, V, StrategyContext(K, .Deep), std.hash_map.default_max_load_percentage);
}

pub fn DeepRecursiveAutoHashMap(comptime K: type, comptime V: type) type {
    return std.HashMap(K, V, StrategyContext(K, .DeepRecursive), std.hash_map.default_max_load_percentage);
}

pub fn DeepRecursiveAutoHashMapUnmanaged(comptime K: type, comptime V: type) type {
    return std.HashMapUnmanaged(K, V, StrategyContext(K, .DeepRecursive), std.hash_map.default_max_load_percentage);
}

const std = @import("std");

pub fn getAutoHashFn(comptime K: type, comptime strat: std.hash.Strategy, comptime Context: type) (fn (Context, K) u64) {
    return struct {
        fn hash(ctx: Context, key: K) u64 {
            _ = ctx;
            var hasher = std.hash.Wyhash.init(0);
            std.hash.autoHashStrat(&hasher, key, strat);
            return hasher.final();
        }
    }.hash;
}

pub fn getAutoEqlFn(comptime K: type, comptime strat: std.hash.Strategy, comptime Context: type) (fn (Context, K, K) bool) {
    return struct {
        fn eql(ctx: Context, a: K, b: K) bool {
            _ = ctx;
            return deepEql(a, b, strat);
        }
    }.eql;
}

pub fn deepEql(a: anytype, b: @TypeOf(a), comptime strat: std.hash.Strategy) bool {
    const T = @TypeOf(a);

    switch (@typeInfo(T)) {
        .@"struct" => |info| {
            inline for (info.fields) |field_info| {
                if (!deepEql(@field(a, field_info.name), @field(b, field_info.name), strat)) return false;
            }
            return true;
        },
        .error_union => {
            if (a) |a_p| {
                if (b) |b_p| return deepEql(a_p, b_p, strat) else |_| return false;
            } else |a_e| {
                if (b) |_| return false else |b_e| return a_e == b_e;
            }
        },
        .@"union" => |info| {
            if (info.tag_type) |UnionTag| {
                const tag_a = std.meta.activeTag(a);
                const tag_b = std.meta.activeTag(b);
                if (tag_a != tag_b) return false;

                inline for (info.fields) |field_info| {
                    if (@field(UnionTag, field_info.name) == tag_a) {
                        return deepEql(@field(a, field_info.name), @field(b, field_info.name), strat);
                    }
                }
                return false;
            }

            @compileError("cannot compare untagged union type " ++ @typeName(T));
        },
        .array => {
            if (a.len != b.len) return false;
            for (a, 0..) |e, i|
                if (!deepEql(e, b[i], strat)) return false;
            return true;
        },
        .vector => |info| {
            var i: usize = 0;
            while (i < info.len) : (i += 1) {
                if (!deepEql(a[i], b[i], strat)) return false;
            }
            return true;
        },
        .pointer => |info| {
            switch (info.size) {
                .one => {
                    if (a == b) return true;
                    return switch (strat) {
                        .Shallow => false,
                        .Deep => deepEql(a.*, b.*, .Shallow),
                        .DeepRecursive => deepEql(a.*, b.*, .DeepRecursive),
                    };
                },
                .many, .c => {
                    if (a == b) return true;
                    if (strat != .Shallow) {
                        @compileError("cannot compare pointer-to-many or C-pointer for deep equality!");
                    }
                },
                .slice => {
                    if (a.len != b.len) return false;
                    if (a.ptr == b.ptr) return true;
                    switch (strat) {
                        .Shallow => return false,
                        .Deep => {
                            for (a, b) |ae, be| {
                                if (!deepEql(ae, be, .Shallow)) return false;
                            }
                            return true;
                        },
                        .DeepRecursive => {
                            for (a, b) |ae, be| {
                                if (!deepEql(ae, be, .DeepRecursive)) return false;
                            }
                            return true;
                        },
                    }
                },
            }
        },
        .optional => {
            if (a == null and b == null) return true;
            if (a == null or b == null) return false;
            return deepEql(a.?, b.?, strat);
        },
        else => return a == b,
    }
}

pub fn StrategyContext(comptime K: type, comptime strat: std.hash.Strategy) type {
    return struct {
        pub const hash = getAutoHashFn(K, strat, @This());
        pub const eql = getAutoEqlFn(K, strat, @This());
    };
}

test {
    try test_map(ShallowAutoHashMap(i32, i32));
    try test_map(DeepAutoHashMap(i32, i32));
    try test_map(DeepRecursiveAutoHashMap(i32, i32));

    try test_map_unmanaged(ShallowAutoHashMapUnmanaged(i32, i32));
    try test_map_unmanaged(DeepAutoHashMapUnmanaged(i32, i32));
    try test_map_unmanaged(DeepRecursiveAutoHashMapUnmanaged(i32, i32));
}

fn test_map(comptime T: type) !void {
    var map = T.init(std.testing.allocator);
    defer map.deinit();

    try map.put(0, 1);
    try std.testing.expectEqual(1, map.get(0));
}

fn test_map_unmanaged(comptime T: type) !void {
    var map: T = .{};
    defer map.deinit(std.testing.allocator);

    try map.put(std.testing.allocator, 0, 1);
    try std.testing.expectEqual(1, map.get(0));
}
