const std = @import("std");
const mimalloc = @import("mimalloc");

test "test mi global allocator" {
    const a = mimalloc.global_allocator;
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(a);
    try list.appendSlice(a, "hello");
    try std.testing.expectEqual(list.items.len, 5);
    try std.testing.expectEqualSlices(u8, list.items, "hello");
}
