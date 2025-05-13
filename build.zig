const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // TODO: Support ZYAN_FORCE_ASSERTS
    const shared = b.option(bool, "ZYCORE_BUILD_SHARED_LIB", "Build Zycore as a shared library") orelse false;
    const no_libc = b.option(bool, "ZYAN_NO_LIBC", "Build Zycore without libc") orelse false;
    const dev_build = b.option(bool, "ZYAN_DEV_MODE", "Build Zycore in developer mode") orelse false;
    const wpo = b.option(bool, "ZYAN_WHOLE_PROGRAM_OPTIMIZATION", "Build Zycore with whole program optimization") orelse false;
    var zycore: *std.Build.Step.Compile = undefined;

    // TODO: Use a module instead so that we can
    // easily specify linkage
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
    defer flags.deinit();

    flags.appendSlice(zycore_flags) catch @panic("Out of memory");
    if (dev_build) flags.appendSlice(dev_flags) catch @panic("Out of memory");
    if (wpo) flags.appendSlice(wpo_flag) catch @panic("Out of memory");

    zycore.addCSourceFiles(.{
        .files = sources,
        .flags = flags.items,
    });

    zycore.addIncludePath(b.path("include"));

    b.installArtifact(zycore);

    // TODO: Unify all of this code within a function so
    // that we don't have to do this multiple times
    const string_exe = b.addExecutable(.{
        .name = "String",
        .target = target,
        .optimize = optimize,
        .link_libc = !no_libc,
    });

    if (!shared) {
        string_exe.root_module.addCMacro("ZYCORE_STATIC_BUILD", "1");
    }

    if (!no_libc) {
        string_exe.linkLibC();
    } else {
        string_exe.root_module.addCMacro("ZYAN_NO_LIBC", "1");
    }

    string_exe.root_module.addCMacro("_CRT_SECURE_NO_WARNINGS", "1");

    string_exe.addCSourceFile(.{
        .file = b.path("examples/String.c"),
        .flags = flags.items,
    });

    string_exe.addIncludePath(b.path("include"));
    string_exe.linkLibrary(zycore);

    // TODO: Install within an examples/ directory
    const string_install = b.addInstallArtifact(string_exe, .{});
    string_install.step.dependOn(b.getInstallStep());

    const vector_exe = b.addExecutable(.{
        .name = "Vector",
        .target = target,
        .optimize = optimize,
        .link_libc = !no_libc,
    });

    if (!shared) {
        vector_exe.root_module.addCMacro("ZYCORE_STATIC_BUILD", "1");
    }

    if (!no_libc) {
        vector_exe.linkLibC();
    } else {
        vector_exe.root_module.addCMacro("ZYAN_NO_LIBC", "1");
    }

    vector_exe.root_module.addCMacro("_CRT_SECURE_NO_WARNINGS", "1");

    vector_exe.addCSourceFile(.{
        .file = b.path("examples/Vector.c"),
        .flags = flags.items,
    });

    vector_exe.addIncludePath(b.path("include"));
    vector_exe.linkLibrary(zycore);

    // TODO: Install within an examples/ directory
    const vector_install = b.addInstallArtifact(vector_exe, .{});
    vector_install.step.dependOn(b.getInstallStep());

    const examples_step = b.step("examples", "Build examples");
    examples_step.dependOn(&string_install.step);
    examples_step.dependOn(&vector_install.step);

    // TODO: Add tests

    // TODO: Perhaps support Doxygen?
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

const headers: []const []const u8 = &.{
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

const sources: []const []const u8 = &.{
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
