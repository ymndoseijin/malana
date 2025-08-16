const std = @import("std");

const ui = @import("ui");
const shaders = @import("shaders");

const State = ui.State;
const graphics = ui.graphics;
const Vec3 = ui.Vec3;
const Vertex = ui.Vertex;
const common = ui.common;

const math = ui.math;
const gl = ui.gl;

var state: *State = undefined;

fn keyDown(_: State.Context, keys: ui.KeyState, mods: i32, dt: f32) !void {
    if (keys.pressed_table[graphics.glfw.GLFW_KEY_Q]) {
        state.main_win.alive = false;
    }

    try state.cam.spatialMove(keys.pressed_table, mods, dt, &state.cam.move, graphics.Camera.DefaultSpatial);
}
pub fn main() !void {
    const PushConstants: graphics.DataDescription = .{ .T = extern struct {
        cam_pos: [3]f32 align(4 * 4),
        cam_transform: math.Mat4 align(4 * 4),
        light_count: i32,
    } };

    const LightArray: graphics.DataDescription = .{ .T = extern struct {
        pos: [3]f32 align(4 * 4),
        intensity: [3]f32 align(4 * 4),
        matrix: math.Mat4 align(4 * 4),
    } };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const ally = gpa.allocator();

    state = try State.init(ally, .{
        .window = .{
            .name = "Base3D",
            .width = 500,
            .height = 500,
            .resizable = true,
        },
        .scene = .{ .flip_z = true },
    });
    defer state.deinit(ally);

    const gpu = &state.main_win.gpu;

    // get obj file
    var arg_it = std.process.args();
    _ = arg_it.next();

    const obj_file = arg_it.next() orelse return error.NotEnoughArguments;

    var obj_parser = try ui.graphics.ObjParse.init(ally);

    // shadow testing

    const shadow_res = 8192;

    const shadow_pass = try graphics.RenderPass.init(gpu, .{
        .format = state.main_win.swapchain.surface_format.format,
        .target = true,
    });
    defer shadow_pass.deinit(gpu);

    const LightObject = struct {
        pub fn init(pos: math.Vec3, intensity: [3]f32) !@This() {
            const shadow_tex = try graphics.Texture.init(state.main_win, shadow_res, shadow_res, .{
                .preferred_format = .depth,
                .compare_less = true,
                .mag_filter = .linear,
                .min_filter = .linear,
            });

            return .{
                .shadow_tex = shadow_tex,
                .pos = pos,
                .intensity = intensity,
            };
        }

        pub fn deinit(light: @This()) void {
            light.shadow_tex.deinit();
        }

        shadow_tex: graphics.Texture,
        pos: math.Vec3,
        intensity: [3]f32,
    };

    const exp = 30;

    const lights = [_]LightObject{
        try LightObject.init(Vec3.init(.{ 2, 0, 2 }), .{ exp, 0, 0 }),
        try LightObject.init(Vec3.init(.{ -2, 2, 2 }), .{ 0, exp, 0 }),
        try LightObject.init(Vec3.init(.{ 2, 2, -2 }), .{ 0, 0, exp }),
    };

    defer for (lights) |light| light.deinit();

    // render screen
    var screen_obj = try obj_parser.parse("resources/screen.obj");
    defer screen_obj.deinit();

    const ScreenPipeline: graphics.PipelineDescription = .{
        .vertex_description = .{
            .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 }, .{ .size = 3 } },
        },
        .render_type = .triangle,
        .depth_test = true,
        .cull_type = .none,
        .sets = &.{.{ .bindings = &.{
            .{ .uniform = .{ .size = graphics.GlobalUniform.getSize() } },
            .{ .uniform = .{ .size = graphics.SpatialMesh.Uniform.getSize() } },
            .{ .sampler = .{} },
        } }},
        .constants_size = PushConstants.getSize(),
        .global_ubo = true,
    };

    const screen_vert = try graphics.Shader.init(gpu.*, &shaders.shadow_vert, .vertex);
    defer screen_vert.deinit(gpu.*);

    const screen_frag = try graphics.Shader.init(gpu.*, &shaders.shadow_frag, .fragment);
    defer screen_frag.deinit(gpu.*);

    var screen_pipeline = try graphics.RenderPipeline.init(ally, .{
        .description = ScreenPipeline,
        .shaders = &.{ screen_vert, screen_frag },
        .rendering = .{ .attachments = &.{.swapchain}, .depth = .depth },
        .gpu = gpu,
        .flipped_z = true,
    });
    defer screen_pipeline.deinit(gpu.*);

    const screen_drawing = try ally.create(graphics.Drawing);
    defer ally.destroy(screen_drawing);

    const color_target: graphics.RenderTarget = .{ .texture = .{
        .color_textures = &.{&state.post_color_tex},
        .depth_texture = &state.post_depth_tex,
        .region = .{},
    } };

    const screen = try graphics.SpatialMesh.init(screen_drawing, state.main_win, .{
        .pipeline = screen_pipeline,
        .target = color_target,
    });
    defer screen_drawing.deinit(ally, gpu.*);

    try screen.drawing.descriptor.updateDescriptorSets(gpu, .{ .samplers = &.{.{ .idx = 2, .textures = &.{lights[0].shadow_tex} }} });

    // get obj model

    var object = try obj_parser.parse(obj_file);
    defer object.deinit();

    const triangle_vert = try graphics.Shader.init(gpu.*, &shaders.vert, .vertex);
    defer triangle_vert.deinit(gpu.*);
    const triangle_frag = try graphics.Shader.init(gpu.*, &shaders.frag, .fragment);
    defer triangle_frag.deinit(gpu.*);

    const TrianglePipeline: graphics.PipelineDescription = .{
        .vertex_description = .{
            .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 }, .{ .size = 3 } },
        },
        .render_type = .triangle,
        .depth_test = true,
        .cull_type = .back,
        .sets = &.{
            .{
                .bindings = &.{
                    .{ .uniform = .{ .size = graphics.GlobalUniform.getSize() } },
                    .{ .uniform = .{ .size = graphics.SpatialMesh.Uniform.getSize() } },
                    .{ .uniform = .{ .size = LightArray.getSize(), .boundless = true } },
                },
            },
            .{
                .bindings = &.{
                    .{ .sampler = .{ .boundless = true } }, // cubemaps
                },
            },
            .{
                .bindings = &.{
                    .{ .sampler = .{ .boundless = true } }, // shadow maps
                },
            },
        },
        .constants_size = PushConstants.getSize(),
        .global_ubo = true,
        .bindless = true,
    };

    var pipeline = try graphics.RenderPipeline.init(ally, .{
        .description = TrianglePipeline,
        .shaders = &.{ triangle_vert, triangle_frag },
        .rendering = .{ .attachments = &.{.swapchain}, .depth = .depth },
        .gpu = gpu,
        .flipped_z = true,
    });
    defer pipeline.deinit(gpu.*);

    var cubemap = try graphics.Texture.init(state.main_win, 1000, 1000, .{ .cubemap = true });
    try cubemap.setCube(ally, .{
        "place/x_minus.png",
        "place/x_plus.png",
        "place/y_plus.png",
        "place/y_minus.png",
        "place/z_plus.png",
        "place/z_minus.png",
    });
    defer cubemap.deinit();

    var other = try graphics.Texture.init(state.main_win, 256, 256, .{ .cubemap = true });
    try other.setCube(ally, .{
        "place2/nx.png",
        "place2/px.png",
        "place2/py.png",
        "place2/ny.png",
        "place2/pz.png",
        "place2/nz.png",
    });
    defer other.deinit();

    const camera_drawing = try state.scene.new();
    const camera_obj = try graphics.SpatialMesh.init(camera_drawing, state.main_win, .{ .pipeline = pipeline, .target = color_target });
    try camera_obj.drawing.descriptor.updateDescriptorSets(gpu, .{ .samplers = &.{.{ .set = 1, .idx = 0, .textures = &.{ cubemap, other } }} });
    for (lights, 0..) |light, i| {
        try camera_obj.drawing.descriptor.updateDescriptorSets(gpu, .{ .samplers = &.{.{
            .set = 2,
            .idx = 0,
            .dst = @intCast(i),
            .textures = &.{light.shadow_tex},
        }} });
    }

    camera_obj.drawing.vert_count = object.vertices.items.len;

    try graphics.SpatialMesh.Pipeline.vertex_description.bindVertex(camera_obj.drawing, gpu, object.vertices.items, object.indices.items, .immediate);

    // shadow drawing
    const ShadowPipeline: graphics.PipelineDescription = .{
        .vertex_description = .{
            .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 }, .{ .size = 3 } },
        },
        .render_type = .triangle,
        .depth_test = true,
        .cull_type = .none,
        .sets = &.{.{ .bindings = &.{
            .{ .uniform = .{ .size = graphics.GlobalUniform.getSize() } },
            .{ .uniform = .{ .size = graphics.SpatialMesh.Uniform.getSize() } },
        } }},
        .constants_size = PushConstants.getSize(),
        .global_ubo = true,
    };
    var shadow_pipeline = try graphics.RenderPipeline.init(ally, .{
        .description = ShadowPipeline,
        .shaders = &.{triangle_vert},
        .rendering = .{ .attachments = &.{}, .depth = .depth },
        .gpu = gpu,
        .flipped_z = true,
    });
    defer shadow_pipeline.deinit(gpu.*);

    var shadow_drawing = try ally.create(graphics.Drawing);
    defer ally.destroy(shadow_drawing);

    const shadow_mesh = try graphics.SpatialMesh.init(shadow_drawing, state.main_win, .{ .pipeline = shadow_pipeline, .target = color_target });
    defer shadow_drawing.deinit(ally, gpu.*);

    shadow_mesh.drawing.vert_count = object.vertices.items.len;
    shadow_mesh.drawing.vertex_buffer = camera_obj.drawing.vertex_buffer;
    defer shadow_mesh.drawing.vertex_buffer = null;
    shadow_mesh.drawing.index_buffer = camera_obj.drawing.index_buffer;
    defer shadow_mesh.drawing.index_buffer = null;

    _ = try state.key_down_manager.subscribe(ally, .{ .func = keyDown });

    // fps counter

    var fps = try graphics.TextFt.init(ally, .{
        .path = "resources/cmunrm.ttf",
        .size = 50,
        .line_spacing = 1,
        .bounding_width = 250,
        //.flip_y = true,
        .scene = &state.scene,
        .target = color_target,
    });
    defer fps.deinit(ally, gpu.*);
    fps.transform.translation = math.Vec2.init(.{ 10, 10 });

    std.debug.print("{any}\n", .{screen_obj.vertices.items});
    try graphics.SpatialMesh.Pipeline.vertex_description.bindVertex(screen.drawing, gpu, screen_obj.vertices.items, screen_obj.indices.items, .immediate);

    const line_vert = try graphics.Shader.init(gpu.*, &shaders.line_vert, .vertex);
    defer line_vert.deinit(gpu.*);
    const line_frag = try graphics.Shader.init(gpu.*, &shaders.line_frag, .fragment);
    defer line_frag.deinit(gpu.*);

    var line_pipeline = try graphics.RenderPipeline.init(ally, .{
        .description = .{
            .vertex_description = .{
                .vertex_attribs = &.{.{ .size = 3 }},
            },
            .render_type = .triangle,
            .depth_test = true,
            .cull_type = .none,
            .sets = &.{.{ .bindings = &.{
                .{ .uniform = .{ .size = graphics.GlobalUniform.getSize() } },
            } }},
            .global_ubo = true,
            .constants_size = PushConstants.getSize(),
        },
        .shaders = &.{ line_vert, line_frag },
        .rendering = .{ .attachments = &.{.swapchain}, .depth = .depth },
        .gpu = gpu,
        .flipped_z = true,
    });
    defer line_pipeline.deinit(gpu.*);
    const line = try graphics.Line.init(&state.scene, .{ .pipeline = line_pipeline, .target = color_target });

    while (state.main_win.alive) {
        const frame = graphics.tracy.namedFrame("Frame");
        defer frame.end();

        const swapchain = &state.main_win.swapchain;
        const builder = &state.command_builder;
        const frame_id = builder.frame_id;

        try swapchain.wait(gpu, frame_id);
        try state.updateEvents();

        var spring_verts = std.ArrayList([3]f32).init(ally);
        defer spring_verts.deinit();
        const spring_count = 1024;

        for (0..spring_count) |i_in| {
            const rot = 18.8495559;
            var i: f32 = @floatFromInt(i_in);
            i /= spring_count;
            i *= rot;

            const scale: f32 = @abs(@sin(@as(f32, @floatCast(state.time))));

            try spring_verts.append(.{ @cos(i), i / rot * scale * 4, @sin(i) });
        }

        //try line.set(ally, .{ .vertices = spring_verts.items });

        const uniform: graphics.SpatialMesh.Uniform.T = .{
            .spatial_pos = .{ 0, 0, 0, 0 },
        };

        var spin = math.rotationY(f32, @floatCast(state.time * 5.0));

        (try camera_obj.drawing.descriptor.getUniformOrCreate(gpu, 0, 1, 0)).setAsUniform(graphics.SpatialMesh.Uniform, uniform);

        //const first_pos = spin.dot(Vec3.init(.{ 2, 2, 2 }));

        for (lights, 0..) |light, i| {
            const spinned_pos = spin.dot(light.pos);
            const light_matrix = math.orthoMatrix(-5, 5, -5, 5, 1.0, 20.0).mul(
                math.lookAtMatrix(spinned_pos, Vec3.init(.{ 0, 0, 0 }), Vec3.init(.{ 0, 1, 0 })),
            );

            (try camera_obj.drawing.descriptor.getUniformOrCreate(gpu, 0, 2, @intCast(i))).setAsUniform(LightArray, .{
                .pos = spinned_pos.val,
                .intensity = light.intensity,
                .matrix = light_matrix,
            });
        }

        try fps.clear();
        try fps.printFmt(ally, "FPS: {}", .{@as(u32, @intFromFloat(1 / state.dt))});

        // begin frame

        // render graphics

        try fps.update(ally, gpu);

        try state.scene.queue.execute();

        state.image_index = try swapchain.acquireImage(gpu, frame_id);
        try builder.beginCommand(gpu);

        for (&lights) |*light| {
            const spinned_pos = spin.dot(light.pos);
            const light_matrix = math.orthoMatrix(-5, 5, -5, 5, 1.0, 20.0).mul(
                math.lookAtMatrix(spinned_pos, Vec3.init(.{ 0, 0, 0 }), Vec3.init(.{ 0, 1, 0 })),
            );
            const data: PushConstants.T = .{
                .cam_pos = Vec3.init(.{ 0, 0, 0 }).val,
                .cam_transform = light_matrix,
                .light_count = lights.len,
            };
            builder.push(PushConstants, gpu, pipeline.pipeline, &data);

            shadow_drawing.render_target = .{ .texture = .{
                .color_textures = &.{},
                .depth_texture = &light.shadow_tex,
                .region = .{},
            } };

            try state.scene.draw(builder, shadow_drawing, state.image_index);
        }

        builder.push(PushConstants, gpu, pipeline.pipeline, &.{
            .cam_pos = state.cam.move.val,
            .cam_transform = state.cam.transform_mat,
            .light_count = lights.len,
        });

        try state.scene.draw(builder, camera_drawing, state.image_index);
        try state.scene.draw(builder, line.drawing, state.image_index);
        try state.scene.draw(builder, state.post_drawing, state.image_index);

        state.scene.end(builder);

        builder.transitionSwapimage(gpu, swapchain.getImage(state.image_index));

        try builder.endCommand(gpu);

        try swapchain.submit(gpu, state.command_builder, .{
            .wait = &.{.{ .semaphore = swapchain.image_acquired[frame_id], .flag = .{ .color_attachment_output_bit = true } }},
            .image_index = state.image_index,
        });
        try swapchain.present(gpu, .{
            .wait = &.{swapchain.swap_images[@intFromEnum(state.image_index)].submit_semaphore},
            .image_index = state.image_index,
        });
    }
}
