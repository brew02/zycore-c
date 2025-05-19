const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const shared = b.option(bool, "shared", "Build Zycore as a shared library") orelse false;
    const no_libc = b.option(bool, "no_libc", "Build Zycore without libc") orelse false;
    const dev_build = b.option(bool, "dev", "Build Zycore in developer mode") orelse false;
    const wpo = b.option(bool, "wpo", "Build Zycore with whole program optimization") orelse false;

    const zycore_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = !no_libc,
    });

    const string_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = !no_libc,
    });

    const vector_mod = b.createModule(.{
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

    const string_exe = b.addExecutable(.{
        .name = "String",
        .root_module = string_mod,
    });

    const vector_exe = b.addExecutable(.{
        .name = "Vector",
        .root_module = vector_mod,
    });

    if (shared) {
        zycore.addWin32ResourceFile(.{
            .file = b.path("resources/VersionInfo.rc"),
        });
    } else {
        zycore.root_module.addCMacro("ZYCORE_STATIC_BUILD", "1");
        string_exe.root_module.addCMacro("ZYCORE_STATIC_BUILD", "1");
        vector_exe.root_module.addCMacro("ZYCORE_STATIC_BUILD", "1");
    }

    if (no_libc) {
        zycore.root_module.addCMacro("ZYAN_NO_LIBC", "1");
        string_exe.root_module.addCMacro("ZYAN_NO_LIBC", "1");
        vector_exe.root_module.addCMacro("ZYAN_NO_LIBC", "1");
    }

    zycore.root_module.addCMacro("ZYCORE_SHOULD_EXPORT", "1");
    zycore.root_module.addCMacro("_CRT_SECURE_NO_WARNINGS", "1");
    string_exe.root_module.addCMacro("_CRT_SECURE_NO_WARNINGS", "1");
    vector_exe.root_module.addCMacro("_CRT_SECURE_NO_WARNINGS", "1");

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

    string_exe.addCSourceFile(.{
        .file = b.path("examples/String.c"),
        .flags = flags.items,
    });
    string_exe.addIncludePath(b.path("include"));

    vector_exe.addCSourceFile(.{
        .file = b.path("examples/Vector.c"),
        .flags = flags.items,
    });

    vector_exe.addIncludePath(b.path("include"));

    b.installArtifact(zycore);
    string_exe.linkLibrary(zycore);
    vector_exe.linkLibrary(zycore);

    const string_install = b.addInstallArtifact(string_exe, .{});
    const vector_install = b.addInstallArtifact(vector_exe, .{});

    string_install.step.dependOn(b.getInstallStep());
    vector_install.step.dependOn(b.getInstallStep());

    const examples_step = b.step("examples", "Build examples");
    examples_step.dependOn(&string_install.step);
    examples_step.dependOn(&vector_install.step);

    const arg_parse_tests_mod = b.createModule(.{
        .root_source_file = b.path("tests/arg_parse.zig"),
        .target = target,
        .optimize = optimize,
    });

    const string_tests_mod = b.createModule(.{
        .root_source_file = b.path("tests/string.zig"),
        .target = target,
        .optimize = optimize,
    });

    const vector_tests_mod = b.createModule(.{
        .root_source_file = b.path("tests/vector.zig"),
        .target = target,
        .optimize = optimize,
    });

    arg_parse_tests_mod.linkLibrary(zycore);
    string_tests_mod.linkLibrary(zycore);
    vector_tests_mod.linkLibrary(zycore);

    const arg_parse_tests = b.addTest(.{
        .root_module = arg_parse_tests_mod,
    });
    arg_parse_tests.addIncludePath(b.path("include"));

    const string_tests = b.addTest(.{
        .root_module = string_tests_mod,
    });
    string_tests.addIncludePath(b.path("include"));

    const vector_tests = b.addTest(.{
        .root_module = vector_tests_mod,
    });
    vector_tests.addIncludePath(b.path("include"));

    const run_arg_parse_tests = b.addRunArtifact(arg_parse_tests);
    const run_string_tests = b.addRunArtifact(string_tests);
    const run_vector_tests = b.addRunArtifact(vector_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_arg_parse_tests.step);
    test_step.dependOn(&run_string_tests.step);
    test_step.dependOn(&run_vector_tests.step);

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
