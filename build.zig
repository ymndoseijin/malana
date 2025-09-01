const std = @import("std");

const Build = std.Build;

//const zilliam = @import("zilliam");

pub fn addShader(b: *std.Build, module: *std.Build.Module, cmd: []const []const u8, comptime name: []const u8, path: []const u8) void {
    const shader_command = b.addSystemCommand(cmd);
    const spv = shader_command.addOutputFileArg(name ++ ".spv");
    shader_command.addFileArg(b.path(path));
    module.addAnonymousImport(name, .{ .root_source_file = spv });
}

pub fn initSlangStep(b: *std.Build, malana_dep: *std.Build.Dependency) *std.Build.Step.Run {
    const tool = b.addExecutable(.{
        .name = "generate_shader",
        .root_module = b.createModule(.{
            .root_source_file = malana_dep.path("parse_slang.zig"),
            .target = b.graph.host,
        }),
    });

    const tool_step = b.addRunArtifact(tool);
    _ = tool_step.addOutputDirectoryArg("shader_comp");
    return tool_step;
}

pub fn addSlangShader(tool_step: *std.Build.Step.Run, b: *std.Build, options: struct {
    module: *std.Build.Module,
    malana_dep: *std.Build.Dependency,
    name: []const u8,
    path: []const u8,
}) void {
    const shader_file = tool_step.addOutputFileArg(b.fmt("{s}.zig", .{options.name}));
    tool_step.addFileArg(b.path(options.path));

    options.module.addAnonymousImport(options.name, .{
        .imports = &.{
            .{
                .name = "malana",
                .module = options.malana_dep.module("malana"),
            },
        },
        .root_source_file = shader_file,
    });
}

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

    const vulkan = b.dependency("vulkan_zig", .{
        .registry = b.path("vk.xml"),
    }).module("vulkan-zig");

    const c_dir = b.addWriteFiles();

    const glfw_import = b.addTranslateC(.{
        .root_source_file = c_dir.add("glfw.h",
            \\#define GLFW_INCLUDE_NONE
            \\#include <GLFW/glfw3.h>
        ),
        .link_libc = true,
        .target = target,
        .optimize = optimize,
    });

    const freetype_import = b.addTranslateC(.{
        .root_source_file = c_dir.add("freetype.h",
            \\#include <freetype/freetype.h>
            \\#include <ft2build.h>
        ),
        .link_libc = true,
        .target = target,
        .optimize = optimize,
    });

    freetype_import.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });

    const stb_image_import = b.addTranslateC(.{
        .root_source_file = b.path("src/stb_image.h"),
        .link_libc = true,
        .target = target,
        .optimize = optimize,
    });

    _ = c_dir.addCopyFile(b.path("src/stb_image.h"), "stb_image.h");

    const vma_dep = b.dependency("vma", .{});
    const vma_import = b.addTranslateC(.{
        .root_source_file = vma_dep.path("include/vk_mem_alloc.h"),
        .link_libc = true,
        .target = target,
        .optimize = optimize,
    });

    _ = c_dir.addCopyFile(vma_dep.path("include/vk_mem_alloc.h"), "vk_mem_alloc.h");

    const graphics = b.createModule(.{
        .root_source_file = b.path("src/graphics/graphics.zig"),
        .imports = &.{
            .{ .name = "math", .module = math },
            .{ .name = "common", .module = common },
            .{ .name = "parsing", .module = parsing },
            .{ .name = "geometry", .module = geometry },
            .{ .name = "img", .module = zigimg_dep.module("zigimg") },
            .{ .name = "vulkan", .module = vulkan },
            .{ .name = "glfw", .module = glfw_import.createModule() },
            .{ .name = "freetype", .module = freetype_import.createModule() },
            .{ .name = "stb_image", .module = stb_image_import.createModule() },
            .{ .name = "vma", .module = vma_import.createModule() },
        },
    });

    graphics.addCSourceFile(.{
        .file = c_dir.add("stb_image.c",
            \\#define STB_IMAGE_IMPLEMENTATION
            \\#include "stb_image.h"
        ),
    });
    graphics.addCSourceFile(.{
        .file = c_dir.add("vma.cpp",
            \\#define VMA_IMPLEMENTATION
            \\#define VMA_STATIC_VULKAN_FUNCTIONS 0
            \\#include "vk_mem_alloc.h"
        ),
    });
    //graphics.addCSourceFile(.{ .file = b.path("src/stb_image.c") });

    inline for (shader_list) |shader| {
        addShader(b, graphics, &.{ "glslangValidator", "-e", "main", "-gVS", "-V", "-o" }, shader[0], shader[1]);
    }

    const numericals = b.createModule(.{
        .root_source_file = b.path("src/numericals.zig"),
        .imports = &.{
            .{ .name = "math", .module = math },
            .{ .name = "common", .module = common },
        },
    });

    const ui_info: std.Build.Module.CreateOptions = .{
        .root_source_file = b.path("src/malana.zig"),
        .imports = &.{
            .{ .name = "img", .module = zigimg_dep.module("zigimg") },
            //.{ .name = "zilliam", .module = zilliam_dep.module("zilliam") },
            .{ .name = "graphics", .module = graphics },
            .{ .name = "geometry", .module = geometry },
            .{ .name = "numericals", .module = numericals },
            .{ .name = "common", .module = common },
            .{ .name = "parsing", .module = parsing },
            .{ .name = "math", .module = math },
        },
    };

    const malana = b.createModule(ui_info);

    _ = b.addModule("malana", ui_info);

    const box2c = b.dependency("box2c", .{});

    const App = struct {
        name: []const u8,
        shaders: []const struct { []const u8, []const u8 },
    };

    const apps: []const App = &.{
        .{
            .name = "simplest",
            .shaders = &.{
                .{
                    "vert",
                    "shaders/shader.vert",
                },
                .{
                    "frag",
                    "shaders/shader.frag",
                },
            },
        },
        .{
            .name = "wave",
            .shaders = &.{
                .{
                    "vert",
                    "shaders/shader.vert",
                },
                .{
                    "frag",
                    "shaders/shader.frag",
                },
                .{
                    "image_vert",
                    "shaders/image.vert",
                },
                .{
                    "image_frag",
                    "shaders/image.frag",
                },
                .{
                    "compute",
                    "shaders/compute.comp",
                },
            },
        },
        .{
            .name = "gravity",
            .shaders = &.{
                .{
                    "vert",
                    "shaders/shader.vert",
                },
                .{
                    "frag",
                    "shaders/shader.frag",
                },
                .{
                    "compute",
                    "shaders/compute.comp",
                },
                .{
                    "points_vert",
                    "shaders/point.vert",
                },
                .{
                    "points_frag",
                    "shaders/point.frag",
                },
            },
        },
        .{
            .name = "base2d",
            .shaders = &.{},
        },
        .{
            .name = "base3d",
            .shaders = &.{
                .{
                    "vert",
                    "shaders/shader.vert",
                },
                .{
                    "frag",
                    "shaders/shader.frag",
                },
                .{
                    "shadow_vert",
                    "shaders/shadow.vert",
                },
                .{
                    "shadow_frag",
                    "shaders/shadow.frag",
                },
                .{
                    "line_vert",
                    "shaders/line.vert",
                },
                .{
                    "line_frag",
                    "shaders/line.frag",
                },
            },
        },
        .{
            .name = "astro",
            .shaders = &.{
                .{
                    "vert",
                    "shaders/shader.vert",
                },
                .{
                    "frag",
                    "shaders/shader.frag",
                },
            },
        },
        .{
            .name = "box-test",
            .shaders = &.{},
        },
        .{
            .name = "shadertoy",
            .shaders = &.{
                .{
                    "vert",
                    "shaders/shader.vert",
                },
            },
        },
    };

    const build_all_step = b.step("all", "Build all");

    inline for (apps) |app| {
        const exe = b.addExecutable(.{
            .name = app.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/" ++ app.name ++ "/main.zig"),
                .target = target,
                .optimize = optimize,
            }),
            //.use_llvm = false,
            //.use_lld = false,
        });

        exe.root_module.addImport("vulkan", vulkan);

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

        exe.linkSystemLibrary("assimp");

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

        exe.root_module.addImport("malana", malana);

        inline for (app.shaders) |shader| {
            addShader(b, exe.root_module, &.{ "glslangValidator", "-e", "main", "-gVS", "-V", "-o" }, shader[0], shader[1]);
        }

        exe.linkSystemLibrary("glfw3");
        exe.linkSystemLibrary("freetype2");
        exe.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
        exe.linkLibC();

        const artifact = b.addInstallArtifact(exe, .{});

        const build_step = b.step(app.name, "Build " ++ app.name);
        build_step.dependOn(&artifact.step);
        build_all_step.dependOn(&artifact.step);

        const run_cmd = b.addRunArtifact(exe);

        run_cmd.step.dependOn(build_step);

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run-" ++ app.name, "Run " ++ app.name);
        run_step.dependOn(&run_cmd.step);
    }

    //const unit_tests = b.addTest(.{
    //    .root_module = b.createModule(.{
    //        .root_source_file = b.path("src/malana/box.zig"),
    //        .target = target,
    //        .optimize = optimize,
    //    }),
    //});

    //unit_tests.root_module.addImport("img", zigimg_dep.module("zigimg"));

    //unit_tests.root_module.addImport("graphics", graphics);
    //unit_tests.root_module.addImport("geometry", geometry);
    //unit_tests.root_module.addImport("numericals", numericals);
    //unit_tests.root_module.addImport("common", common);
    //unit_tests.root_module.addImport("parsing", parsing);
    //unit_tests.root_module.addImport("math", math);

    //unit_tests.linkSystemLibrary("glfw3");
    //unit_tests.linkSystemLibrary("freetype2");

    //unit_tests.linkLibC();

    //const run_unit_tests = b.addRunArtifact(unit_tests);

    //const test_step = b.step("test", "Run unit tests");
    //test_step.dependOn(&run_unit_tests.step);
}

pub fn linkLibraries(b: *std.Build, exe: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, tracy: ?[]const u8) void {
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

    exe.linkSystemLibrary("glfw3");
    exe.linkSystemLibrary("freetype2");
    exe.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
    exe.linkSystemLibrary("assimp");
    exe.linkLibC();
}
