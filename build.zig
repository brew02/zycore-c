const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const use_asserts = b.option(bool, "ZYAN_FORCE_ASSERTS", "Build Zycore with asserts in release builds") orelse false;
    const shared = b.option(bool, "ZYCORE_BUILD_SHARED_LIB", "Build Zycore as a shared library") orelse false;
    const no_libc = b.option(bool, "ZYAN_NO_LIBC", "Build Zycore without libc") orelse false;
    const dev_build = b.option(bool, "ZYAN_DEV_MODE", "Build Zycore in developer mode") orelse false;
    const wpo = b.option(bool, "ZYAN_WHOLE_PROGRAM_OPTIMIZATION", "Build Zycore with whole program optimization") orelse false;

    const zycore_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = !no_libc,
    });

    const linkage = if (shared) std.builtin.LinkMode.dynamic else std.builtin.LinkMode.static;

    const zycore = b.addLibrary(.{
        .name = "Zycore",
        .linkage = linkage,
        .root_module = zycore_mod,
    });

    if (shared) {
        zycore.addWin32ResourceFile(.{
            .file = b.path("resources/VersionInfo.rc"),
        });
    } else {
        zycore.root_module.addCMacro("ZYCORE_STATIC_BUILD", "1");
    }

    if (use_asserts) {
        switch (optimize) {
            .ReleaseFast, .ReleaseSafe, .ReleaseSmall => zycore.root_module.addCMacro("UNDEBUG", "1"),
            else => {},
        }
    }

    if (!no_libc) {
        zycore.linkLibC();
    } else {
        zycore.root_module.addCMacro("ZYAN_NO_LIBC", "1");
    }

    zycore.root_module.addCMacro("ZYCORE_SHOULD_EXPORT", "1");
    zycore.root_module.addCMacro("_CRT_SECURE_NO_WARNINGS", "1");

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

    const string_exe = b.addExecutable(.{
        .name = "String",
        .target = target,
        .optimize = optimize,
        .link_libc = !no_libc,
    });

    if (use_asserts) {
        switch (optimize) {
            .ReleaseFast, .ReleaseSafe, .ReleaseSmall => string_exe.root_module.addCMacro("UNDEBUG", "1"),
            else => {},
        }
    }

    addExampleMacros(string_exe, no_libc, shared);

    string_exe.addCSourceFile(.{
        .file = b.path("examples/String.c"),
        .flags = flags.items,
    });

    string_exe.addIncludePath(b.path("include"));
    string_exe.linkLibrary(zycore);

    const string_install = b.addInstallArtifact(string_exe, .{});

    string_install.step.dependOn(b.getInstallStep());

    const vector_exe = b.addExecutable(.{
        .name = "Vector",
        .target = target,
        .optimize = optimize,
        .link_libc = !no_libc,
    });

    if (use_asserts) {
        switch (optimize) {
            .ReleaseFast, .ReleaseSafe, .ReleaseSmall => vector_exe.root_module.addCMacro("UNDEBUG", "1"),
            else => {},
        }
    }

    addExampleMacros(vector_exe, no_libc, shared);

    vector_exe.addCSourceFile(.{
        .file = b.path("examples/Vector.c"),
        .flags = flags.items,
    });

    vector_exe.addIncludePath(b.path("include"));
    vector_exe.linkLibrary(zycore);

    const vector_install = b.addInstallArtifact(vector_exe, .{});

    vector_install.step.dependOn(b.getInstallStep());

    const examples_step = b.step("examples", "Build examples");
    examples_step.dependOn(&string_install.step);
    examples_step.dependOn(&vector_install.step);

    // TODO: Add tests

    // TODO: Perhaps support Doxygen?
}

fn addExampleMacros(exe: *std.Build.Step.Compile, no_libc: bool, shared: bool) void {
    if (!shared) {
        exe.root_module.addCMacro("ZYCORE_STATIC_BUILD", "1");
    }

    if (no_libc) {
        exe.root_module.addCMacro("ZYAN_NO_LIBC", "1");
    }

    exe.root_module.addCMacro("_CRT_SECURE_NO_WARNINGS", "1");
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
