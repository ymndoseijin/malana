const std = @import("std");
const ShaderCompileStep = @import("shader_build.zig");

const Build = std.Build;

const zilliam = @import("zilliam");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zilliam_dep = b.dependency("zilliam", .{
        .target = target,
        .optimize = optimize,
    });

    const Algebra = zilliam.geo.Algebra(f32, 3, 0, 1);
    const Blades = zilliam.blades.Blades(Algebra, .{});
    const Type = Blades.Types[22];

    const generated_glsl = comptime zilliam.glsl_gen.generateGlsl(Type, "Motor");

    const zigimg_dep = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    const freetype_dep = b.dependency("freetype", .{
        .target = target,
        .optimize = optimize,
    });

    const glfw_dep = b.dependency("glfw", .{
        .target = target,
        .optimize = optimize,
    });

    const gl = b.createModule(.{ .root_source_file = .{ .path = "src/graphics/gl.zig" } });
    const math = b.createModule(.{ .root_source_file = .{ .path = "src/math.zig" } });
    const common = b.createModule(.{ .root_source_file = .{ .path = "src/common.zig" } });
    const parsing = b.createModule(.{
        .root_source_file = .{ .path = "src/parsing/parsing.zig" },
        .imports = &.{
            .{ .name = "math", .module = math },
            .{ .name = "common", .module = common },
        },
    });

    const geometry = b.createModule(.{
        .root_source_file = .{ .path = "src/geometry.zig" },
        .imports = &.{
            .{ .name = "math", .module = math },
            .{ .name = "zilliam", .module = zilliam_dep.module("zilliam") },
            .{ .name = "common", .module = common },
            .{ .name = "parsing", .module = parsing },
        },
    });

    const elem_shaders = ShaderCompileStep.create(
        b,
        &[_][]const u8{ "glslc", "--target-env=vulkan1.2" },
        "-o",
    );

    const shader_list = .{
        .{ "sprite_frag", "src/graphics/elems/shaders/sprite/shader.frag" },
        .{ "sprite_vert", "src/graphics/elems/shaders/sprite/shader.vert" },
        .{ "color_frag", "src/graphics/elems/shaders/color_rect/shader.frag" },
        .{ "color_vert", "src/graphics/elems/shaders/color_rect/shader.vert" },
        .{ "text_frag", "src/graphics/elems/shaders/text/shader.frag" },
        .{ "text_vert", "src/graphics/elems/shaders/text/shader.vert" },
        .{ "textft_frag", "src/graphics/elems/shaders/textft/shader.frag" },
        .{ "textft_vert", "src/graphics/elems/shaders/textft/shader.vert" },
        .{ "post_frag", "src/ui/shaders/post.frag" },
        .{ "post_vert", "src/ui/shaders/post.vert" },
    };
    inline for (shader_list) |shader| {
        elem_shaders.add(shader[0], shader[1], .{});
    }

    const graphics = b.createModule(.{
        .root_source_file = .{ .path = "src/graphics/graphics.zig" },
        .imports = &.{
            .{ .name = "math", .module = math },
            .{ .name = "common", .module = common },
            .{ .name = "gl", .module = gl },
            .{ .name = "parsing", .module = parsing },
            .{ .name = "geometry", .module = geometry },
            .{ .name = "img", .module = zigimg_dep.module("zigimg") },
            .{ .name = "freetype", .module = freetype_dep.module("mach-freetype") },
            .{ .name = "elem_shaders", .module = elem_shaders.getModule() },
        },
    });

    const numericals = b.createModule(.{
        .root_source_file = .{ .path = "src/numericals.zig" },
        .imports = &.{
            .{ .name = "math", .module = math },
            .{ .name = "common", .module = common },
        },
    });

    const ui_info: std.Build.Module.CreateOptions = .{
        .root_source_file = .{ .path = "src/ui.zig" },
        .imports = &.{
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

    const App = struct {
        name: []const u8,
        shaders: []const struct { []const u8, []const u8, ShaderCompileStep.ShaderOptions },
    };

    const apps: []const App = &.{
        .{
            .name = "simplest",
            .shaders = &.{
                .{ "vert", "shaders/shader.vert", .{} },
                .{ "frag", "shaders/shader.frag", .{} },
            },
        },
        .{
            .name = "base2d",
            .shaders = &.{},
        },
        .{
            .name = "base3d",
            .shaders = &.{
                .{ "vert", "shaders/shader.vert", .{ .preamble = generated_glsl } },
                .{ "frag", "shaders/shader.frag", .{} },
            },
        },
        .{
            .name = "box-test",
            .shaders = &.{},
        },
        .{
            .name = "shadertoy",
            .shaders = &.{
                .{ "vert", "shaders/shader.vert", .{} },
            },
        },
    };

    inline for (apps) |app| {
        const exe = b.addExecutable(.{
            .name = app.name,
            // In this case the main source file is merely a path, however, in more
            // complicated build scripts, this could be a generated file.
            .root_source_file = .{ .path = "examples/" ++ app.name ++ "/main.zig" },
            .target = target,
            .optimize = optimize,
        });

        exe.root_module.addImport("ui", ui);

        const shaders = ShaderCompileStep.create(
            b,
            &[_][]const u8{ "glslc", "--target-env=vulkan1.2" },
            "-o",
        );
        inline for (app.shaders) |shader| {
            shaders.add(shader[0], "examples/" ++ app.name ++ "/" ++ shader[1], shader[2]);
        }
        exe.root_module.addImport("shaders", shaders.getModule());

        exe.linkLibrary(glfw_dep.artifact("glfw"));
        //exe.linkLibrary(freetype_dep.artifact("freetype"));

        exe.linkLibC();

        const artifact = b.addInstallArtifact(exe, .{});

        const build_step = b.step(app.name, "Build " ++ app.name);
        build_step.dependOn(&artifact.step);

        const run_cmd = b.addRunArtifact(exe);

        run_cmd.step.dependOn(build_step);

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run-" ++ app.name, "Run " ++ app.name);
        run_step.dependOn(&run_cmd.step);
    }

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/ui/box.zig" },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.root_module.addImport("img", zigimg_dep.module("zigimg"));

    unit_tests.root_module.addImport("graphics", graphics);
    unit_tests.root_module.addImport("geometry", geometry);
    unit_tests.root_module.addImport("numericals", numericals);
    unit_tests.root_module.addImport("common", common);
    unit_tests.root_module.addImport("parsing", parsing);
    unit_tests.root_module.addImport("gl", gl);
    unit_tests.root_module.addImport("math", math);

    unit_tests.linkLibrary(glfw_dep.artifact("glfw"));
    //unit_tests.linkLibrary(freetype_dep.artifact("freetype"));

    unit_tests.linkLibC();

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
