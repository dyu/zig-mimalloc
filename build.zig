const std = @import("std");
const translate_c = @import("translate_c");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.addModule("mimalloc", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ======================================================================
    // deps

    const c_sources = b.dependency("mimalloc-src", .{
        .link_libc = true,
    });
    lib_mod.addIncludePath(c_sources.path("include"));

    const dep_translate_c = b.dependency("translate_c", .{});

    const translate_mimalloc_h: translate_c.Translator = .init(dep_translate_c, .{
        .c_source_file = c_sources.path("include/mimalloc.h"),
        .target = target,
        .optimize = optimize,
    });

    lib_mod.addImport("c", translate_mimalloc_h.mod);

    // ======================================================================
    // opts

    const secure = b.option(bool, "secure", "Use full security mitigations (like guard pages, allocation randomization, double-free mitigation, and free-list corruption detection)") orelse false;
    const debug_full = b.option(bool, "debug_full", "Use full internal heap invariant checking in DEBUG mode (expensive)") orelse switch (optimize) {
        .Debug => true,
        .ReleaseSafe, .ReleaseFast, .ReleaseSmall => false,
    };
    const padding = b.option(bool, "padding", "Enable padding to detect heap block overflow (always on in DEBUG or SECURE mode, or with Valgrind/ASAN)") orelse false;

    if (target.result.isMuslLibC()) {
        lib_mod.addCMacro("MI_LIBC_MUSL", "1");
    }

    if (secure) {
        lib_mod.addCMacro("MI_SECURE", "4");
    }

    if (debug_full) {
        lib_mod.addCMacro("MI_DEBUG", "3");
    }

    if (padding) {
        lib_mod.addCMacro("MI_PADDING", "1");
    }

    switch (optimize) {
        .ReleaseFast, .ReleaseSmall => {
            lib_mod.addCMacro("NDEBUG", "1");
        },
        .Debug, .ReleaseSafe => {},
    }

    const tsan = lib_mod.sanitize_thread != null and lib_mod.sanitize_thread.?;
    const ubsan = lib_mod.sanitize_c != null and lib_mod.sanitize_c.? != .off;
    const valgrind = lib_mod.valgrind != null and lib_mod.valgrind.?;

    if (tsan) {
        lib_mod.addCMacro("MI_TSAN", "1");
    }

    if (ubsan) {
        lib_mod.addCMacro("MI_UBSAN", "1");
        lib_mod.addCSourceFile(.{ .file = b.path("src/ubsan_main.cpp") });
        lib_mod.addIncludePath(c_sources.path("src"));
        lib_mod.link_libcpp = true;
    } else {
        lib_mod.addCSourceFile(.{ .file = c_sources.path("src/static.c") });
    }

    if (valgrind) {
        lib_mod.addCMacro("MI_TRACK_VALGRIND", "1");
    }

    // ======================================================================

    const tests = b.step("test", "Run all tests");

    const lib_test = b.addTest(.{
        // .root_module = zpp,
        // .root_source_file = b.path("tests/test.zig"),
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/test.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .filters = b.option(
            []const []const u8,
            "test-filter",
            "Limit the amount of tests to run",
        ) orelse &.{},
        // .test_runner = .{ .path = b.path("test_runner.zig"), .mode = .simple },
    });
    lib_test.root_module.addImport("mimalloc", lib_mod);

    tests.dependOn(&b.addRunArtifact(lib_test).step);
}
