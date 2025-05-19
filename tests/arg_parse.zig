const std = @import("std");
const s = @import("status.zig");

const c = @cImport({
    @cInclude("Zycore/ArgParse.h");
    @cInclude("Zycore/Status.h");
    @cInclude("Zycore/Vector.h");
});

fn cvtStringView(sv: *const c.ZyanStringView) [:0]const u8 {
    var buf: ?[*:0]const u8 = null;
    if (c.ZYAN_FAILED(c.ZyanStringViewGetData(sv, @ptrCast(&buf))) == 1) @panic("Failed to get string data");
    var len: c.ZyanUSize = 0;
    if (c.ZYAN_FAILED(c.ZyanStringViewGetSize(sv, &len)) == 1) @panic("Failed to get string length");

    if (buf) |val| {
        const ret = std.mem.span(val);
        if (ret.len != len) @panic("String length is not equal");
        return ret;
    } else {
        @panic("String buffer is null");
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

test "too few args: unnamed args" {
    const status, _, const err_tok = unnamedArgTest(5, 5);

    try std.testing.expectEqual(s.ZYAN_MAKE_STATUS(@as(c_uint, 1), c.ZYAN_MODULE_ARGPARSE, @as(c_uint, 0x01)), status);
    try std.testing.expectEqual(null, err_tok);
}

test "too many args: unnamed args" {
    const status, _, const err_tok = unnamedArgTest(1, 1);

    try std.testing.expectEqual(s.ZYAN_MAKE_STATUS(@as(c_uint, 1), c.ZYAN_MODULE_ARGPARSE, @as(c_uint, 0x02)), status);
    try std.testing.expectEqualStrings("xxx", std.mem.span(err_tok.?));
}

test "perfect fit: unnamed args" {
    const status, const parsed, _ = unnamedArgTest(2, 2);

    try std.testing.expect(c.ZYAN_SUCCESS(status));

    var size: c.ZyanUSize = 0;
    try std.testing.expect(c.ZYAN_SUCCESS(c.ZyanVectorGetSize(&parsed, &size)));
    try std.testing.expectEqual(2, size);

    var arg: ?*const c.ZyanArgParseArg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 0)));
    try std.testing.expect(arg != null);
    try std.testing.expect(arg.?.has_value == 1);
    try std.testing.expectEqualStrings("a", cvtStringView(&arg.?.value));

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 1)));
    try std.testing.expect(arg != null);
    try std.testing.expect(arg.?.has_value == 1);
    try std.testing.expectEqualStrings("xxx", cvtStringView(&arg.?.value));
}

test "mixed bool and value args: single dash" {
    const argv = &[_][*:0]const u8{
        "./test",
        "-aio42",
        "-n",
        "xxx",
    };

    const args: []const c.ZyanArgParseDefinition = &.{
        .{ .name = "-o", .boolean = c.ZYAN_FALSE, .required = c.ZYAN_FALSE },
        .{ .name = "-a", .boolean = c.ZYAN_TRUE, .required = c.ZYAN_FALSE },
        .{ .name = "-n", .boolean = c.ZYAN_FALSE, .required = c.ZYAN_FALSE },
        .{ .name = "-i", .boolean = c.ZYAN_TRUE, .required = c.ZYAN_FALSE },
        .{ .name = null, .boolean = c.ZYAN_FALSE, .required = c.ZYAN_FALSE },
    };

    const cfg: c.ZyanArgParseConfig = .{
        .argv = @ptrCast(@constCast(argv)),
        .argc = 4,
        .min_unnamed_args = 0,
        .max_unnamed_args = 0,
        .args = @ptrCast(@constCast(args)),
    };

    var parsed: c.ZyanVector = undefined;
    @memset(std.mem.asBytes(&parsed), 0);
    const status = c.ZyanArgParse(&cfg, &parsed, null);
    try std.testing.expect(c.ZYAN_SUCCESS(status));

    var size: c.ZyanUSize = 0;
    try std.testing.expect(c.ZYAN_SUCCESS(c.ZyanVectorGetSize(&parsed, &size)));
    try std.testing.expectEqual(4, size);

    var arg: ?*const c.ZyanArgParseArg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 0)));
    try std.testing.expect(arg != null);
    try std.testing.expectEqualStrings("-a", std.mem.span(arg.?.def.*.name));
    try std.testing.expect(arg.?.has_value == 0);

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 1)));
    try std.testing.expect(arg != null);
    try std.testing.expectEqualStrings("-i", std.mem.span(arg.?.def.*.name));
    try std.testing.expect(arg.?.has_value == 0);

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 2)));
    try std.testing.expect(arg != null);
    try std.testing.expectEqualStrings("-o", std.mem.span(arg.?.def.*.name));
    try std.testing.expect(arg.?.has_value == 1);
    try std.testing.expectEqualStrings("42", cvtStringView(&arg.?.value));

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 3)));
    try std.testing.expect(arg != null);
    try std.testing.expectEqualStrings("-n", std.mem.span(arg.?.def.*.name));
    try std.testing.expect(arg.?.has_value == 1);
    try std.testing.expectEqualStrings("xxx", cvtStringView(&arg.?.value));
}

test "perfect fit: double dashed args" {
    const argv = &[_][*:0]const u8{
        "./test",
        "--help",
        "--stuff",
        "1337",
    };

    const args: []const c.ZyanArgParseDefinition = &.{
        .{ .name = "--help", .boolean = c.ZYAN_TRUE, .required = c.ZYAN_FALSE },
        .{ .name = "--stuff", .boolean = c.ZYAN_FALSE, .required = c.ZYAN_FALSE },
        .{ .name = null, .boolean = c.ZYAN_FALSE, .required = c.ZYAN_FALSE },
    };

    const cfg: c.ZyanArgParseConfig = .{
        .argv = @ptrCast(@constCast(argv)),
        .argc = 4,
        .min_unnamed_args = 0,
        .max_unnamed_args = 0,
        .args = @ptrCast(@constCast(args)),
    };

    var parsed: c.ZyanVector = undefined;
    @memset(std.mem.asBytes(&parsed), 0);
    const status = c.ZyanArgParse(&cfg, &parsed, null);
    try std.testing.expect(c.ZYAN_SUCCESS(status));

    var size: c.ZyanUSize = 0;
    try std.testing.expect(c.ZYAN_SUCCESS(c.ZyanVectorGetSize(&parsed, &size)));
    try std.testing.expectEqual(2, size);

    var arg: ?*const c.ZyanArgParseArg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 0)));
    try std.testing.expect(arg != null);
    try std.testing.expectEqualStrings("--help", std.mem.span(arg.?.def.*.name));
    try std.testing.expect(arg.?.has_value == 0);

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 1)));
    try std.testing.expect(arg != null);
    try std.testing.expectEqualStrings("--stuff", std.mem.span(arg.?.def.*.name));
    try std.testing.expect(arg.?.has_value == 1);
    try std.testing.expectEqualStrings("1337", cvtStringView(&arg.?.value));
}

test "missing required arg: mixed args" {
    const argv = &[_][*:0]const u8{
        "./test",
        "blah.c",
        "woof.moo",
    };

    const args: []const c.ZyanArgParseDefinition = &.{
        .{ .name = "--feature-xyz", .boolean = c.ZYAN_TRUE, .required = c.ZYAN_FALSE },
        .{ .name = "-n", .boolean = c.ZYAN_FALSE, .required = c.ZYAN_TRUE },
        .{ .name = null, .boolean = c.ZYAN_FALSE, .required = c.ZYAN_FALSE },
    };

    const cfg: c.ZyanArgParseConfig = .{
        .argv = @ptrCast(@constCast(argv)),
        .argc = 3,
        .min_unnamed_args = 0,
        .max_unnamed_args = 100,
        .args = @ptrCast(@constCast(args)),
    };

    var parsed: c.ZyanVector = undefined;
    var err_tok: ?[*:0]const u8 = null;
    @memset(std.mem.asBytes(&parsed), 0);
    const status = c.ZyanArgParse(&cfg, &parsed, @ptrCast(&err_tok));
    try std.testing.expectEqual(s.ZYAN_MAKE_STATUS(@as(c_uint, 1), c.ZYAN_MODULE_ARGPARSE, @as(c_uint, 0x04)), status);
    try std.testing.expectEqualStrings("-n", std.mem.span(err_tok.?));
}

test "stuff: mixed args" {
    const argv = &[_][*:0]const u8{
        "./test",
        "--feature-xyz",
        "-n5",
        "blah.c",
        "woof.moo",
    };

    const args: []const c.ZyanArgParseDefinition = &.{
        .{ .name = "--feature-xyz", .boolean = c.ZYAN_TRUE, .required = c.ZYAN_FALSE },
        .{ .name = "-n", .boolean = c.ZYAN_FALSE, .required = c.ZYAN_FALSE },
        .{ .name = null, .boolean = c.ZYAN_FALSE, .required = c.ZYAN_FALSE },
    };

    const cfg: c.ZyanArgParseConfig = .{
        .argv = @ptrCast(@constCast(argv)),
        .argc = 5,
        .min_unnamed_args = 0,
        .max_unnamed_args = 100,
        .args = @ptrCast(@constCast(args)),
    };

    var parsed: c.ZyanVector = undefined;
    @memset(std.mem.asBytes(&parsed), 0);
    const status = c.ZyanArgParse(&cfg, &parsed, null);
    try std.testing.expect(c.ZYAN_SUCCESS(status));

    var size: c.ZyanUSize = 0;
    try std.testing.expect(c.ZYAN_SUCCESS(c.ZyanVectorGetSize(&parsed, &size)));
    try std.testing.expectEqual(4, size);

    var arg: ?*const c.ZyanArgParseArg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 0)));
    try std.testing.expect(arg != null);
    try std.testing.expectEqualStrings("--feature-xyz", std.mem.span(arg.?.def.*.name));
    try std.testing.expect(arg.?.has_value == 0);

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 1)));
    try std.testing.expect(arg != null);
    try std.testing.expectEqualStrings("-n", std.mem.span(arg.?.def.*.name));
    try std.testing.expect(arg.?.has_value == 1);
    try std.testing.expectEqualStrings("5", cvtStringView(&arg.?.value));

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 2)));
    try std.testing.expect(arg != null);
    try std.testing.expect(arg.?.def == null);
    try std.testing.expect(arg.?.has_value == 1);
    try std.testing.expectEqualStrings("blah.c", cvtStringView(&arg.?.value));

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 3)));
    try std.testing.expect(arg != null);
    try std.testing.expect(arg.?.def == null);
    try std.testing.expect(arg.?.has_value == 1);
    try std.testing.expectEqualStrings("woof.moo", cvtStringView(&arg.?.value));
}
