const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const zilliam_dep = b.dependency("zilliam", .{
        .target = target,
        .optimize = optimize,
    });

    const zigimg_dep = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    const freetype_dep = b.dependency("freetype", .{
        .target = target,
        .optimize = optimize,
    });

    const gl = b.createModule(.{ .source_file = .{ .path = "src/graphics/gl.zig" } });
    const math = b.createModule(.{ .source_file = .{ .path = "src/math.zig" } });
    const common = b.createModule(.{ .source_file = .{ .path = "src/common.zig" } });
    const parsing = b.createModule(.{
        .source_file = .{ .path = "src/parsing/parsing.zig" },
        .dependencies = &.{
            .{ .name = "math", .module = math },
            .{ .name = "common", .module = common },
        },
    });

    const geometry = b.createModule(.{
        .source_file = .{ .path = "src/geometry.zig" },
        .dependencies = &.{
            .{ .name = "math", .module = math },
            .{ .name = "zilliam", .module = zilliam_dep.module("zilliam") },
            .{ .name = "common", .module = common },
            .{ .name = "parsing", .module = parsing },
        },
    });

    const graphics = b.createModule(.{
        .source_file = .{ .path = "src/graphics/graphics.zig" },
        .dependencies = &.{
            .{ .name = "math", .module = math },
            .{ .name = "common", .module = common },
            .{ .name = "gl", .module = gl },
            .{ .name = "parsing", .module = parsing },
            .{ .name = "geometry", .module = geometry },
            .{ .name = "img", .module = zigimg_dep.module("zigimg") },
            .{ .name = "freetype", .module = freetype_dep.module("mach-freetype") },
        },
    });

    const numericals = b.createModule(.{
        .source_file = .{ .path = "src/numericals.zig" },
        .dependencies = &.{
            .{ .name = "math", .module = math },
            .{ .name = "common", .module = common },
        },
    });

    var ui_info: std.Build.CreateModuleOptions = .{
        .source_file = .{ .path = "src/ui.zig" },
        .dependencies = &.{
            .{ .name = "img", .module = zigimg_dep.module("zigimg") },
            .{ .name = "freetype", .module = freetype_dep.module("mach-freetype") },
            .{ .name = "zilliam", .module = zilliam_dep.module("zilliam") },
            .{ .name = "graphics", .module = graphics },
            .{ .name = "geometry", .module = geometry },
            .{ .name = "numericals", .module = numericals },
            .{ .name = "common", .module = common },
            .{ .name = "parsing", .module = parsing },
            .{ .name = "gl", .module = gl },
            .{ .name = "math", .module = math },
        },
    };

    const ui = b.createModule(ui_info);

    _ = b.addModule("ui", ui_info);

    inline for (.{"base2d"}) |app| {
        const exe = b.addExecutable(.{
            .name = app,
            // In this case the main source file is merely a path, however, in more
            // complicated build scripts, this could be a generated file.
            .root_source_file = .{ .path = "examples/" ++ app ++ "/main.zig" },
            .target = target,
            .optimize = optimize,
        });

        exe.addModule("ui", ui);

        linkLibraries(b, exe);

        exe.linkLibC();

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);

        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run-" ++ app, "Run " ++ app);
        run_step.dependOn(&run_cmd.step);
    }

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "examples/plotter/ui.zig" },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.addModule("img", zigimg_dep.module("zigimg"));

    unit_tests.addModule("graphics", graphics);
    unit_tests.addModule("geometry", geometry);
    unit_tests.addModule("numericals", numericals);
    unit_tests.addModule("common", common);
    unit_tests.addModule("parsing", parsing);
    unit_tests.addModule("gl", gl);
    unit_tests.addModule("math", math);

    linkLibraries(b, unit_tests);

    unit_tests.linkLibC();

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

pub fn linkLibraries(b: *std.Build, step: *std.build.CompileStep) void {
    const freetype_dep = b.dependency("freetype", .{
        .target = step.target,
        .optimize = step.optimize,
    });
    step.linkLibrary(b.dependency("glfw", .{
        .target = step.target,
        .optimize = step.optimize,
    }).artifact("glfw"));
    @import("freetype").linkFreetype(freetype_dep.builder, step);
}
