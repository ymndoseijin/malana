const std = @import("std");
const ShaderCompileStep = @import("shader_build.zig");

const Build = std.Build;

//const zilliam = @import("zilliam");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tracy = b.option([]const u8, "tracy", "Enable Tracy integration. Supply path to Tracy source");

    //const zilliam_dep = b.dependency("zilliam", .{
    //    .target = target,
    //    .optimize = optimize,
    //});

    //const Algebra = zilliam.geo.Algebra(f32, 3, 0, 1);
    //const Blades = zilliam.blades.Blades(Algebra, .{});
    //const Type = Blades.Types[22];

    //const generated_glsl = comptime zilliam.glsl_gen.generateGlsl(Type, "Motor");

    const zigimg_dep = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    const gl = b.createModule(.{ .root_source_file = b.path("src/graphics/gl.zig") });
    const math = b.createModule(.{ .root_source_file = b.path("src/math.zig") });
    const common = b.createModule(.{ .root_source_file = b.path("src/common.zig") });
    const parsing = b.createModule(.{
        .root_source_file = b.path("src/parsing/parsing.zig"),
        .imports = &.{
            .{ .name = "math", .module = math },
            .{ .name = "common", .module = common },
        },
    });

    const geometry = b.createModule(.{
        .root_source_file = b.path("src/geometry.zig"),
        .imports = &.{
            .{ .name = "math", .module = math },
            //.{ .name = "zilliam", .module = zilliam_dep.module("zilliam") },
            .{ .name = "common", .module = common },
            .{ .name = "parsing", .module = parsing },
        },
    });

    const elem_shaders = ShaderCompileStep.create(
        b,
        &[_][]const u8{ "glslc", "-g", "--target-env=vulkan1.2" },
        "-o",
    );

    const shader_list = .{
        .{ "sprite_frag", "src/graphics/elems/shaders/sprite/shader.frag" },
        .{ "sprite_vert", "src/graphics/elems/shaders/sprite/shader.vert" },
        .{ "sprite_batch_frag", "src/graphics/elems/shaders/spritebatch/shader.frag" },
        .{ "sprite_batch_vert", "src/graphics/elems/shaders/spritebatch/shader.vert" },
        .{ "color_frag", "src/graphics/elems/shaders/color_rect/shader.frag" },
        .{ "color_vert", "src/graphics/elems/shaders/color_rect/shader.vert" },
        .{ "text_frag", "src/graphics/elems/shaders/text/shader.frag" },
        .{ "text_vert", "src/graphics/elems/shaders/text/shader.vert" },
        .{ "textft_frag", "src/graphics/elems/shaders/textft/shader.frag" },
        .{ "textft_vert", "src/graphics/elems/shaders/textft/shader.vert" },
        .{ "post_frag", "src/ui/shaders/post.frag" },
        .{ "post_vert", "src/ui/shaders/post.vert" },
        .{ "line_frag", "src/graphics/elems/shaders/line/shader.frag" },
        .{ "line_vert", "src/graphics/elems/shaders/line/shader.vert" },
    };
    inline for (shader_list) |shader| {
        elem_shaders.add(shader[0], shader[1], .{});
    }

    const graphics = b.createModule(.{
        .root_source_file = b.path("src/graphics/graphics.zig"),
        .imports = &.{
            .{ .name = "math", .module = math },
            .{ .name = "common", .module = common },
            .{ .name = "gl", .module = gl },
            .{ .name = "parsing", .module = parsing },
            .{ .name = "geometry", .module = geometry },
            .{ .name = "img", .module = zigimg_dep.module("zigimg") },
            .{ .name = "elem_shaders", .module = elem_shaders.getModule() },
        },
    });
    graphics.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });

    const numericals = b.createModule(.{
        .root_source_file = b.path("src/numericals.zig"),
        .imports = &.{
            .{ .name = "math", .module = math },
            .{ .name = "common", .module = common },
        },
    });

    const ui_info: std.Build.Module.CreateOptions = .{
        .root_source_file = b.path("src/ui.zig"),
        .imports = &.{
            .{ .name = "img", .module = zigimg_dep.module("zigimg") },
            //.{ .name = "zilliam", .module = zilliam_dep.module("zilliam") },
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

    const box2c = b.dependency("box2c", .{});

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
            .name = "wave",
            .shaders = &.{
                .{ "vert", "shaders/shader.vert", .{} },
                .{ "frag", "shaders/shader.frag", .{} },
                .{ "image_vert", "shaders/image.vert", .{} },
                .{ "image_frag", "shaders/image.frag", .{} },
                .{ "compute", "shaders/compute.comp", .{} },
            },
        },
        .{
            .name = "gravity",
            .shaders = &.{
                .{ "vert", "shaders/shader.vert", .{} },
                .{ "frag", "shaders/shader.frag", .{} },
                .{ "compute", "shaders/compute.comp", .{} },
                .{ "points_vert", "shaders/point.vert", .{} },
                .{ "points_frag", "shaders/point.frag", .{} },
            },
        },
        .{
            .name = "base2d",
            .shaders = &.{},
        },
        .{
            .name = "base3d",
            .shaders = &.{
                .{ "vert", "shaders/shader.vert", .{} },
                .{ "frag", "shaders/shader.frag", .{} },
                .{ "shadow_vert", "shaders/shadow.vert", .{} },
                .{ "shadow_frag", "shaders/shadow.frag", .{} },
                .{ "line_vert", "shaders/line.vert", .{} },
                .{ "line_frag", "shaders/line.frag", .{} },
            },
        },
        .{
            .name = "astro",
            .shaders = &.{
                .{ "vert", "shaders/shader.vert", .{} },
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
            .root_source_file = b.path("examples/" ++ app.name ++ "/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        if (tracy) |tracy_path| {
            const client_cpp = b.pathJoin(
                &[_][]const u8{ tracy_path, "public", "TracyClient.cpp" },
            );

            // On mingw, we need to opt into windows 7+ to get some features required by tracy.
            const tracy_c_flags: []const []const u8 = if (target.result.os.tag == .windows and target.result.abi == .gnu)
                &[_][]const u8{ "-DTRACY_ENABLE=1", "-fno-sanitize=undefined", "-D_WIN32_WINNT=0x601" }
            else
                &[_][]const u8{ "-DTRACY_ENABLE=1", "-fno-sanitize=undefined" };

            exe.addIncludePath(.{ .cwd_relative = tracy_path });
            exe.addCSourceFile(.{ .file = .{ .cwd_relative = client_cpp }, .flags = tracy_c_flags });
            exe.root_module.linkSystemLibrary("c++", .{ .use_pkg_config = .no });
            exe.linkLibC();

            if (target.result.os.tag == .windows) {
                exe.linkSystemLibrary("dbghelp");
                exe.linkSystemLibrary("ws2_32");
            }
        }

        exe.addIncludePath(box2c.path("src"));
        exe.addIncludePath(box2c.path("include"));
        exe.addIncludePath(box2c.path("extern/simde"));

        inline for (&.{
            "src/aabb.c",
            "src/allocate.c",
            "src/array.c",
            "src/bitset.c",
            "src/block_array.c",
            "src/body.c",
            "src/broad_phase.c",
            "src/constraint_graph.c",
            "src/contact.c",
            "src/contact_solver.c",
            "src/core.c",
            "src/distance.c",
            "src/distance_joint.c",
            "src/dynamic_tree.c",
            "src/geometry.c",
            "src/hull.c",
            "src/id_pool.c",
            "src/island.c",
            "src/joint.c",
            "src/manifold.c",
            "src/math_functions.c",
            "src/motor_joint.c",
            "src/mouse_joint.c",
            "src/prismatic_joint.c",
            "src/revolute_joint.c",
            "src/shape.c",
            "src/solver.c",
            "src/solver_set.c",
            "src/stack_allocator.c",
            "src/table.c",
            "src/timer.c",
            "src/types.c",
            "src/weld_joint.c",
            "src/wheel_joint.c",
            "src/world.c",
        }) |path| {
            exe.addCSourceFile(.{
                .file = box2c.path(path),
                .flags = &.{},
            });
        }

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

        exe.linkSystemLibrary("glfw3");
        exe.linkSystemLibrary("freetype2");
        exe.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
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
        .root_source_file = b.path("src/ui/box.zig"),
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

    unit_tests.linkSystemLibrary("glfw3");
    unit_tests.linkSystemLibrary("freetype2");

    unit_tests.linkLibC();

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
