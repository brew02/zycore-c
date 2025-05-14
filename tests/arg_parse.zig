const std = @import("std");

const c = @cImport({
    @cInclude("Zycore/ArgParse.h");
    @cInclude("Zycore/Status.h");
    @cInclude("Zycore/Vector.h");
});

pub fn ZYAN_MAKE_STATUS(comptime err: u32, comptime module: u32, comptime code: u32) c.ZyanStatus {
    return ((err & 1) << 31) | ((module & 0x7FF) << 20) | (code & 0xFFFFF);
}

fn cvtStringView(sv: *const c.ZyanStringView) ?[:0]const u8 {
    var buf: ?[*:0]const u8 = null;
    if (c.ZYAN_FAILED(c.ZyanStringViewGetData(sv, @ptrCast(&buf))) == 1) return null;
    var len: c.ZyanUSize = 0;
    if (c.ZYAN_FAILED(c.ZyanStringViewGetSize(sv, &len)) == 1) return null;

    if (buf) |val| {
        const ret = std.mem.span(val);
        if (ret.len != len) return null;
        return ret;
    } else {
        return null;
    }
}

fn unnamedArgTest(min: c.ZyanUSize, max: c.ZyanUSize) struct {
    c.ZyanStatus,
    c.ZyanVector,
    ?[*:0]const u8,
} {
    const argv = &[_][*:0]const u8{
        "./test",
        "a",
        "xxx",
    };

    const cfg: c.ZyanArgParseConfig = .{
        .argv = @ptrCast(@constCast(argv)),
        .argc = 3,
        .min_unnamed_args = min,
        .max_unnamed_args = max,
        .args = null,
    };

    var parsed: c.ZyanVector = undefined;
    var err_tok: ?[*:0]const u8 = null;
    @memset(std.mem.asBytes(&parsed), 0);
    const status = c.ZyanArgParse(&cfg, &parsed, @ptrCast(&err_tok));
    return .{ status, parsed, err_tok };
}

test "too few unnamed args" {
    const status, _, const err_tok = unnamedArgTest(5, 5);

    try std.testing.expectEqual(ZYAN_MAKE_STATUS(@as(c_uint, 1), c.ZYAN_MODULE_ARGPARSE, @as(c_uint, 0x01)), status);
    try std.testing.expectEqual(null, err_tok);
}

test "too many unnamed args" {
    const status, _, const err_tok = unnamedArgTest(1, 1);

    try std.testing.expectEqual(ZYAN_MAKE_STATUS(@as(c_uint, 1), c.ZYAN_MODULE_ARGPARSE, @as(c_uint, 0x02)), status);
    try std.testing.expectEqualStrings("xxx", std.mem.span(err_tok.?));
}

test "perfect fit unnamed args" {
    const status, const parsed, _ = unnamedArgTest(2, 2);

    try std.testing.expect(c.ZYAN_SUCCESS(status));
    var size: c.ZyanUSize = 0;

    try std.testing.expect(c.ZYAN_SUCCESS(c.ZyanVectorGetSize(&parsed, &size)));
    try std.testing.expectEqual(2, size);

    var arg: ?*const c.ZyanArgParseArg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 0)));
    try std.testing.expect(arg != null);
    try std.testing.expect(arg.?.has_value == 1);

    var val = cvtStringView(&arg.?.value);
    try std.testing.expect(val != null);
    try std.testing.expectEqualStrings("a", val.?);

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 1)));
    try std.testing.expect(arg != null);
    try std.testing.expect(arg.?.has_value == 1);

    val = cvtStringView(&arg.?.value);
    try std.testing.expect(val != null);
    try std.testing.expectEqualStrings("xxx", val.?);
}
