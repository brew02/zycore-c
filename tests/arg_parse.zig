const std = @import("std");
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;
const zyanMakeStatus = @import("status.zig").zyanMakeStatus;

const status_success = zyanMakeStatus(0, c.ZYAN_MODULE_ZYCORE, 0x00);
const status_too_few_args = zyanMakeStatus(1, c.ZYAN_MODULE_ARGPARSE, 0x01);
const status_too_many_args = zyanMakeStatus(1, c.ZYAN_MODULE_ARGPARSE, 0x02);
const status_required_arg_missing = zyanMakeStatus(1, c.ZYAN_MODULE_ARGPARSE, 0x04);

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

    try expectEqual(status_too_few_args, status);
    try expectEqual(null, err_tok);
}

test "too many args: unnamed args" {
    const status, _, const err_tok = unnamedArgTest(1, 1);

    try expectEqual(status_too_many_args, status);
    try expectEqualStrings("xxx", std.mem.span(err_tok.?));
}

test "perfect fit: unnamed args" {
    const status, const parsed, _ = unnamedArgTest(2, 2);

    try expectEqual(status_success, status);

    var size: c.ZyanUSize = 0;
    try expectEqual(status_success, c.ZyanVectorGetSize(&parsed, &size));
    try expectEqual(2, size);

    var arg: ?*const c.ZyanArgParseArg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 0)));
    try expect(arg != null);
    try expect(arg.?.has_value == 1);
    try expectEqualStrings("a", cvtStringView(&arg.?.value));

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 1)));
    try expect(arg != null);
    try expect(arg.?.has_value == 1);
    try expectEqualStrings("xxx", cvtStringView(&arg.?.value));
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
    try expectEqual(status_success, status);

    var size: c.ZyanUSize = 0;
    try expectEqual(status_success, c.ZyanVectorGetSize(&parsed, &size));
    try expectEqual(4, size);

    var arg: ?*const c.ZyanArgParseArg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 0)));
    try expect(arg != null);
    try expectEqualStrings("-a", std.mem.span(arg.?.def.*.name));
    try expect(arg.?.has_value == 0);

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 1)));
    try expect(arg != null);
    try expectEqualStrings("-i", std.mem.span(arg.?.def.*.name));
    try expect(arg.?.has_value == 0);

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 2)));
    try expect(arg != null);
    try expectEqualStrings("-o", std.mem.span(arg.?.def.*.name));
    try expect(arg.?.has_value == 1);
    try expectEqualStrings("42", cvtStringView(&arg.?.value));

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 3)));
    try expect(arg != null);
    try expectEqualStrings("-n", std.mem.span(arg.?.def.*.name));
    try expect(arg.?.has_value == 1);
    try expectEqualStrings("xxx", cvtStringView(&arg.?.value));
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
    try expectEqual(status_success, status);

    var size: c.ZyanUSize = 0;
    try expectEqual(status_success, c.ZyanVectorGetSize(&parsed, &size));
    try expectEqual(2, size);

    var arg: ?*const c.ZyanArgParseArg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 0)));
    try expect(arg != null);
    try expectEqualStrings("--help", std.mem.span(arg.?.def.*.name));
    try expect(arg.?.has_value == 0);

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 1)));
    try expect(arg != null);
    try expectEqualStrings("--stuff", std.mem.span(arg.?.def.*.name));
    try expect(arg.?.has_value == 1);
    try expectEqualStrings("1337", cvtStringView(&arg.?.value));
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
    try expectEqual(status_required_arg_missing, status);
    try expectEqualStrings("-n", std.mem.span(err_tok.?));
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
    try expectEqual(status_success, status);

    var size: c.ZyanUSize = 0;
    try expectEqual(status_success, c.ZyanVectorGetSize(&parsed, &size));
    try expectEqual(4, size);

    var arg: ?*const c.ZyanArgParseArg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 0)));
    try expect(arg != null);
    try expectEqualStrings("--feature-xyz", std.mem.span(arg.?.def.*.name));
    try expect(arg.?.has_value == 0);

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 1)));
    try expect(arg != null);
    try expectEqualStrings("-n", std.mem.span(arg.?.def.*.name));
    try expect(arg.?.has_value == 1);
    try expectEqualStrings("5", cvtStringView(&arg.?.value));

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 2)));
    try expect(arg != null);
    try expect(arg.?.def == null);
    try expect(arg.?.has_value == 1);
    try expectEqualStrings("blah.c", cvtStringView(&arg.?.value));

    arg = @alignCast(@ptrCast(c.ZyanVectorGet(&parsed, 3)));
    try expect(arg != null);
    try expect(arg.?.def == null);
    try expect(arg.?.has_value == 1);
    try expectEqualStrings("woof.moo", cvtStringView(&arg.?.value));
}
