const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;
const assert = std.debug.assert;
const zyanMakeStatus = @import("status.zig").zyanMakeStatus;

const status_success = zyanMakeStatus(0, c.ZYAN_MODULE_ZYCORE, 0x00);
const status_invalid_argument = zyanMakeStatus(1, c.ZYAN_MODULE_ZYCORE, 0x04);
const status_not_enough_memory = zyanMakeStatus(1, c.ZYAN_MODULE_ZYCORE, 0x0A);

const c = @cImport({
    @cInclude("Zycore/Allocator.h");
    @cInclude("Zycore/String.h");
    @cInclude("Zycore/LibC.h");
});

fn allocatorAllocate(allocator: ?*c.ZyanAllocator, p: ?*?*anyopaque, element_size: c.ZyanUSize, n: c.ZyanUSize) callconv(.c) c.ZyanStatus {
    assert(allocator != null);
    assert(p != null);
    assert(element_size != 0);
    assert(n != 0);

    p.?.* = c.ZYAN_MALLOC(element_size * n);
    if (p.?.* == null) {
        return status_not_enough_memory;
    }

    return status_success;
}

fn allocatorReallocate(allocator: ?*c.ZyanAllocator, p: ?*?*anyopaque, element_size: c.ZyanUSize, n: c.ZyanUSize) callconv(.c) c.ZyanStatus {
    assert(allocator != null);
    assert(p != null);
    assert(element_size != 0);
    assert(n != 0);

    const x = c.ZYAN_REALLOC(p.?.*, element_size * n);
    if (x == null) {
        return status_not_enough_memory;
    }
    p.?.* = x;

    return status_success;
}

fn allocatorDeallocate(allocator: ?*c.ZyanAllocator, p: ?*anyopaque, element_size: c.ZyanUSize, n: c.ZyanUSize) callconv(.c) c.ZyanStatus {
    assert(allocator != null);
    assert(p != null);
    assert(element_size != 0);
    assert(n != 0);

    c.ZYAN_FREE(p);

    return status_success;
}

test "init dynamic: string test" {
    var string: c.ZyanString = undefined;
    try expectEqual(status_success, c.ZyanStringInit(&string, 0));
    try expectEqual(c.ZYAN_STRING_DEFAULT_GROWTH_FACTOR, string.vector.growth_factor);
    try expectEqual(c.ZYAN_STRING_DEFAULT_SHRINK_THRESHOLD, string.vector.shrink_threshold);
    try expectEqual(@as(c.ZyanUSize, 1), string.vector.size);
    try expectEqual(@as(c.ZyanUSize, c.ZYAN_STRING_MIN_CAPACITY + 1), string.vector.capacity);
    try expectEqual(@sizeOf(c_char), string.vector.element_size);
    try expect(c.ZYAN_NULL != string.vector.data);
    try expectEqual(status_success, c.ZyanStringDestroy(&string));
}

test "init static: string test" {
    var string: c.ZyanString = undefined;

    const buffer = struct {
        var str: [32:0]u8 = undefined;
    };

    try expectEqual(status_invalid_argument, c.ZyanStringInitCustomBuffer(&string, &buffer.str, 0));
    try expectEqual(status_success, c.ZyanStringInitCustomBuffer(&string, &buffer.str, buffer.str.len));

    const allocator: ?*c.ZyanAllocator = string.vector.allocator;
    try expect(null == allocator);
    try expectEqual(1, string.vector.growth_factor);
    try expectEqual(0, string.vector.shrink_threshold);
    try expectEqual(@as(c.ZyanUSize, 1), string.vector.size);
    try expectEqual(buffer.str.len, string.vector.capacity);
    try expectEqual(@sizeOf(c_char), string.vector.element_size);
    try expect(c.ZYAN_NULL != string.vector.data);

    const data: *[32:0]u8 = @alignCast(@ptrCast(string.vector.data.?));
    try expectEqual(&buffer.str, data);
    try expectEqual(status_success, c.ZyanStringDestroy(&string));
}

test "init advanced: string test" {
    var string: c.ZyanString = undefined;
    var allocator: c.ZyanAllocator = undefined;

    try expectEqual(status_success, c.ZyanAllocatorInit(&allocator, allocatorAllocate, allocatorReallocate, allocatorDeallocate));
    try expectEqual(status_success, c.ZyanStringInitEx(&string, 0, &allocator, 1, 0));
    try expectEqual(1, string.vector.growth_factor);
    try expectEqual(0, string.vector.shrink_threshold);
    try expectEqual(@as(c.ZyanUSize, 1), string.vector.size);
    try expectEqual(@as(c.ZyanUSize, c.ZYAN_STRING_MIN_CAPACITY + 1), string.vector.capacity);
    try expectEqual(@sizeOf(c_char), string.vector.element_size);
    try expect(c.ZYAN_NULL != string.vector.data);
    try expectEqual(status_success, c.ZyanStringDestroy(&string));
}
