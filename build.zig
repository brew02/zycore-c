const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const shared = b.option(bool, "ZYCORE_BUILD_SHARED_LIB", "Build Zycore as a shared library") orelse false;
    const no_libc = b.option(bool, "ZYAN_NO_LIBC", "Build Zycore without libc") orelse false;
    const dev_build = b.option(bool, "ZYAN_DEV_MODE", "Build Zycore in developer mode") orelse false;
    const wpo = b.option(bool, "ZYAN_WHOLE_PROGRAM_OPTIMIZATION", "Build Zycore with whole program optimization") orelse false;
    var zycore: *std.Build.Step.Compile = undefined;

    if (shared) {
        zycore = b.addSharedLibrary(.{
            .name = "Zycore",
            .target = target,
            .optimize = optimize,
            .link_libc = !no_libc,
        });

        zycore.addWin32ResourceFile(.{
            .file = b.path("resources/VersionInfo.rc"),
        });
    } else {
        zycore = b.addStaticLibrary(.{
            .name = "Zycore",
            .target = target,
            .optimize = optimize,
            .link_libc = !no_libc,
        });

        zycore.root_module.addCMacro("ZYCORE_STATIC_BUILD", "1");
    }

    if (!no_libc) {
        zycore.linkLibC();
    } else {
        zycore.root_module.addCMacro("ZYAN_NO_LIBC", "1");
    }

    zycore.root_module.addCMacro("ZYCORE_SHOULD_EXPORT", "1");
    zycore.root_module.addCMacro("_CRT_SECURE_NO_WARNINGS", "1");

    for (headers) |h| zycore.installHeader(b.path(h), h);
    var flags = std.ArrayList([]const u8).init(b.allocator);

    flags.appendSlice(zycore_flags) catch @panic("Out of memory");
    if (dev_build) flags.appendSlice(dev_flags) catch @panic("Out of memory");
    if (wpo) flags.appendSlice(wpo_flag) catch @panic("Out of memory");

    zycore.addCSourceFiles(.{
        .files = &sources,
        .flags = flags.toOwnedSlice() catch @panic("Out of memory"),
    });

    zycore.addIncludePath(b.path("include"));

    b.installArtifact(zycore);
}

const zycore_flags: []const []const u8 = &.{
    "-std=c11",
};

const dev_flags: []const []const u8 = &.{
    "-Wall",
    "-pedantic",
    "-Wextra",
    "-Werror",
};

const wpo_flag: []const []const u8 = &.{
    "-flto",
};

const headers = [_][]const u8{
    "include/Zycore/API/Memory.h",
    "include/Zycore/API/Process.h",
    "include/Zycore/API/Synchronization.h",
    "include/Zycore/API/Terminal.h",
    "include/Zycore/API/Thread.h",

    "include/Zycore/Internal/AtomicGNU.h",
    "include/Zycore/Internal/AtomicMSVC.h",

    "include/Zycore/Allocator.h",
    "include/Zycore/ArgParse.h",
    "include/Zycore/Atomic.h",
    "include/Zycore/Bitset.h",
    "include/Zycore/Comparison.h",
    "include/Zycore/Defines.h",
    "include/Zycore/Format.h",
    "include/Zycore/LibC.h",
    "include/Zycore/List.h",
    "include/Zycore/Object.h",
    "include/Zycore/Status.h",
    "include/Zycore/String.h",
    "include/Zycore/Types.h",
    "include/Zycore/Vector.h",
    "include/Zycore/Zycore.h",
};

const sources = [_][]const u8{
    "src/API/Memory.c",
    "src/API/Process.c",
    "src/API/Synchronization.c",
    "src/API/Terminal.c",
    "src/API/Thread.c",

    "src/Allocator.c",
    "src/ArgParse.c",
    "src/Bitset.c",
    "src/Format.c",
    "src/List.c",
    "src/String.c",
    "src/Vector.c",
    "src/Zycore.c",
};
