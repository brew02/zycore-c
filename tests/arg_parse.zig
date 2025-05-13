const std = @import("std");

const c = @cImport({
    @cInclude("Zycore/ArgParse.h");
    @cInclude("Zycore/Status.h");
    @cInclude("Zycore/Vector.h");
});

pub fn ZYAN_MAKE_STATUS(comptime err: u32, comptime module: u32, comptime code: u32) c.ZyanStatus {
    return ((err & 1) << 31) | ((module & 0x7FF) << 20) | (code & 0xFFFFF);
}

fn unnamedArgTest(min: c.ZyanUSize, max: c.ZyanUSize) struct {
    c.ZyanStatus,
    c.ZyanVector,
    ?[]const u8,
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
    var err_tok: ?[]const u8 = null;
    @memset(std.mem.asBytes(&parsed), 0);
    const status = c.ZyanArgParse(&cfg, &parsed, @ptrCast(&err_tok));
    return .{ status, parsed, err_tok };
}

test "too few unnamed args" {
    const status, _, const err_tok = unnamedArgTest(5, 5);

    try std.testing.expectEqual(ZYAN_MAKE_STATUS(@as(c_uint, 1), c.ZYAN_MODULE_ARGPARSE, @as(c_uint, 0x01)), status);
    try std.testing.expectEqual(null, err_tok);
}
