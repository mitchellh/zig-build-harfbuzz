const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const coretext_enabled = b.option(bool, "enable-coretext", "Build coretext") orelse false;
    const freetype_enabled = b.option(bool, "enable-freetype", "Build freetype") orelse false;

    const lib = b.addStaticLibrary(.{
        .name = "harfbuzz",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();
    lib.linkLibCpp();
    if (target.isLinux()) {
        lib.linkSystemLibrary("m");
    }

    const freetype_dep = b.dependency("freetype", .{ .target = target, .optimize = optimize });
    lib.linkLibrary(freetype_dep.artifact("freetype"));
    lib.addIncludePath(.{ .path = "upstream/src" });

    var flags = std.ArrayList([]const u8).init(b.allocator);
    defer flags.deinit();
    try flags.appendSlice(&.{
        "-DHAVE_STDBOOL_H",
    });
    if (!target.isWindows()) {
        try flags.appendSlice(&.{
            "-DHAVE_UNISTD_H",
            "-DHAVE_SYS_MMAN_H",
            "-DHAVE_PTHREAD=1",
        });
    }
    if (freetype_enabled) try flags.appendSlice(&.{
        "-DHAVE_FREETYPE=1",

        // Let's just assume a new freetype
        "-DHAVE_FT_GET_VAR_BLEND_COORDINATES=1",
        "-DHAVE_FT_SET_VAR_BLEND_COORDINATES=1",
        "-DHAVE_FT_DONE_MM_VAR=1",
        "-DHAVE_FT_GET_TRANSFORM=1",
    });
    if (coretext_enabled) {
        try flags.appendSlice(&.{"-DHAVE_CORETEXT=1"});
        lib.linkFramework("ApplicationServices");
    }

    lib.addCSourceFiles(srcs, flags.items);

    lib.installHeadersDirectoryOptions(.{
        .source_dir = .{ .path = "upstream/src" },
        .install_dir = .header,
        .install_subdir = "",
        .exclude_extensions = &.{
            ".build",
            ".c",
            ".cc",
            ".hh",
            ".in",
            ".py",
            ".rs",
            ".rl",
            ".ttf",
            ".txt",
        },
    });

    b.installArtifact(lib);
}

const srcs = &.{
    "upstream/src/harfbuzz.cc",
};
