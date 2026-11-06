const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

// const mi = @import("c.zig");
const mi = @import("c");

var garbage_state: i32 = 0;

var vtable = Allocator.VTable{
    .alloc = mimalloc_alloc,
    .resize = mimalloc_resize,
    .free = mimalloc_free,
    .remap = mimalloc_remap,
};

pub const allocator = Allocator{
    .ptr = &garbage_state,
    .vtable = &vtable,
};

fn mimalloc_alloc(_: *anyopaque, len: usize, log2_align: Alignment, _: usize) ?[*]u8 {
    assert(len > 0);
    // assert(log2_align > 0);
    // const alignment = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_align));
    const alignment = log2_align.toByteUnits();
    const res_ptr = mi.mi_malloc_aligned(len, alignment) orelse return null;
    return @ptrCast(res_ptr);
}

fn mimalloc_remap(_: *anyopaque, _: []u8, _: Alignment, _: usize, _: usize) ?[*]u8 {
    return null;
}

fn mimalloc_resize(_: *anyopaque, buf: []u8, _: Alignment, new_len: usize, _: usize) bool {
    assert(new_len > 0);
    assert(buf.len > 0);
    // assert(log2_align > 0);

    return mi.mi_expand(buf.ptr, new_len) != null;
}
fn mimalloc_free(_: *anyopaque, buf: []u8, log2_align: Alignment, _: usize) void {
    // assert(log2_align > 0);
    // const alignment = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_align));
    const alignment = log2_align.toByteUnits();
    return mi.mi_free_aligned(buf.ptr, alignment);
}
