const std = @import("std");
const s = @import("status.zig");

const c = @cImport({
    @cInclude("Zycore/Allocator.h");
    @cInclude("Zycore/String.h");
});

test "init dynamic: string test" {
    const success = comptime s.ZYAN_MAKE_STATUS(@as(c_uint, 0), c.ZYAN_MODULE_ZYCORE, @as(c_uint, 0x00));

    var string: c.ZyanString = undefined;
    try std.testing.expectEqual(success, c.ZyanStringInit(&string, 0));
    try std.testing.expectEqual(c.ZYAN_STRING_DEFAULT_GROWTH_FACTOR, string.vector.growth_factor);
    try std.testing.expectEqual(c.ZYAN_STRING_DEFAULT_SHRINK_THRESHOLD, string.vector.shrink_threshold);
    try std.testing.expectEqual(@as(c.ZyanUSize, 1), string.vector.size);
    try std.testing.expectEqual(@as(c.ZyanUSize, c.ZYAN_STRING_MIN_CAPACITY + 1), string.vector.capacity);
    try std.testing.expectEqual(@sizeOf(c_char), string.vector.element_size);
    try std.testing.expect(c.ZYAN_NULL != string.vector.data);
    try std.testing.expectEqual(success, c.ZyanStringDestroy(&string));
}
