const std = @import("std");

const ui = @import("ui");
const shaders = @import("shaders");

const Ui = ui.Ui;
const graphics = ui.graphics;
const Vec3 = ui.Vec3;
const Vertex = ui.Vertex;
const common = ui.common;

const math = ui.math;
const gl = ui.gl;

var state: *Ui = undefined;

fn key_down(keys: ui.KeyState, mods: i32, dt: f32) !void {
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

    state = try Ui.init(ally, .{
        .window = .{ .name = "box test", .width = 500, .height = 500, .resizable = true, .preferred_format = .srgb },
        .scene = .{ .flip_z = true },
    });
    defer state.deinit(ally);

    const gc = &state.main_win.gc;
    const builder = &state.command_builder;

    // get obj file
    var arg_it = std.process.args();
    _ = arg_it.next();

    const obj_file = arg_it.next() orelse return error.NotEnoughArguments;

    var obj_parser = try ui.graphics.ObjParse.init(ally);

    // shadow testing

    const shadow_res = 1024;

    const shadow_pass = try graphics.RenderPass.init(&state.main_win.gc, .{
        .format = state.main_win.swapchain.surface_format.format,
        .target = true,
    });

    const LightObject = struct {
        pub fn init(pass: graphics.RenderPass, pos: math.Vec3, intensity: [3]f32) !@This() {
            const shadow_tex = try graphics.Texture.init(state.main_win, shadow_res, shadow_res, .{
                .preferred_format = .depth,
                .sampled = true,
                .compare_less = true,
                .mag_filter = .linear,
                .min_filter = .linear,
            });

            const shadow_diffuse = try graphics.Texture.init(state.main_win, shadow_res, shadow_res, .{
                .preferred_format = .srgb,
                .is_render_target = true,
            });

            const shadow_buffer = try graphics.Framebuffer.init(&state.main_win.gc, .{
                .attachments = &.{ shadow_diffuse.image_view, shadow_tex.image_view },
                .render_pass = pass.pass,
                .width = shadow_res,
                .height = shadow_res,
            });

            return .{
                .shadow_pass = pass,
                .shadow_tex = shadow_tex,
                .shadow_diffuse = shadow_diffuse,
                .shadow_buffer = shadow_buffer,
                .pos = pos,
                .intensity = intensity,
            };
        }

        shadow_pass: graphics.RenderPass,
        shadow_tex: graphics.Texture,
        shadow_diffuse: graphics.Texture,
        shadow_buffer: graphics.Framebuffer,
        pos: math.Vec3,
        intensity: [3]f32,
    };

    //var xoshiro = std.Random.Xoshiro256.init(252);
    //const random = xoshiro.random();
    const exp = 30;

    const lights = [_]LightObject{
        try LightObject.init(shadow_pass, Vec3.init(.{ 2, 0, 2 }), .{ exp, 0, 0 }),
        try LightObject.init(shadow_pass, Vec3.init(.{ -2, 2, 2 }), .{ 0, exp, 0 }),
        try LightObject.init(shadow_pass, Vec3.init(.{ 2, 2, -2 }), .{ 0, 0, exp }),
    };

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
        .bindings = &.{
            .{ .uniform = .{ .size = graphics.GlobalUniform.getSize() } },
            .{ .uniform = .{ .size = graphics.SpatialMesh.Uniform.getSize() } },
            .{ .sampler = .{} },
        },
        .constants_size = PushConstants.getSize(),
        .global_ubo = true,
    };

    const screen_vert = try graphics.Shader.init(state.main_win.gc, &shaders.shadow_vert, .vertex);
    defer screen_vert.deinit(state.main_win.gc);

    const screen_frag = try graphics.Shader.init(state.main_win.gc, &shaders.shadow_frag, .fragment);
    defer screen_frag.deinit(state.main_win.gc);

    var screen_pipeline = try graphics.RenderPipeline.init(ally, .{
        .description = ScreenPipeline,
        .shaders = &.{ screen_vert, screen_frag },
        .render_pass = state.first_pass,
        .gc = &state.main_win.gc,
        .flipped_z = true,
    });
    defer screen_pipeline.deinit(&state.main_win.gc);

    const screen_drawing = try ally.create(graphics.Drawing);
    const screen = try graphics.SpatialMesh.init(screen_drawing, state.main_win, .{
        .pos = math.Vec3.init(.{ 0, 0, 0 }),
        .pipeline = screen_pipeline,
    });
    try screen.drawing.updateDescriptorSets(ally, .{ .samplers = &.{.{ .idx = 2, .textures = &.{lights[0].shadow_tex} }} });

    // get obj model

    var object = try obj_parser.parse(obj_file);
    defer object.deinit();

    const triangle_vert = try graphics.Shader.init(state.main_win.gc, &shaders.vert, .vertex);
    defer triangle_vert.deinit(state.main_win.gc);
    const triangle_frag = try graphics.Shader.init(state.main_win.gc, &shaders.frag, .fragment);
    defer triangle_frag.deinit(state.main_win.gc);

    const TrianglePipeline: graphics.PipelineDescription = .{
        .vertex_description = .{
            .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 }, .{ .size = 3 } },
        },
        .render_type = .triangle,
        .depth_test = true,
        .cull_type = .back,
        .bindings = &.{
            .{ .uniform = .{ .size = graphics.GlobalUniform.getSize() } },
            .{ .uniform = .{ .size = graphics.SpatialMesh.Uniform.getSize() } },
            .{ .uniform = .{ .size = LightArray.getSize(), .boundless = true } },
            .{ .sampler = .{ .boundless = true } }, // cubemaps
            .{ .sampler = .{ .boundless = true } }, // shadow maps
        },
        .constants_size = PushConstants.getSize(),
        .global_ubo = true,
        .bindless = true,
    };

    var pipeline = try graphics.RenderPipeline.init(ally, .{
        .description = TrianglePipeline,
        .shaders = &.{ triangle_vert, triangle_frag },
        .render_pass = state.first_pass,
        .gc = &state.main_win.gc,
        .flipped_z = true,
    });
    defer pipeline.deinit(&state.main_win.gc);

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
    const camera_obj = try graphics.SpatialMesh.init(camera_drawing, state.main_win, .{
        .pos = math.Vec3.init(.{ 0, 0, 0 }),
        .pipeline = pipeline,
    });
    try camera_obj.drawing.updateDescriptorSets(ally, .{ .samplers = &.{.{ .idx = 3, .textures = &.{ cubemap, other } }} });
    for (lights, 0..) |light, i| {
        try camera_obj.drawing.updateDescriptorSets(ally, .{ .samplers = &.{.{ .idx = 4, .dst = @intCast(i), .textures = &.{light.shadow_tex} }} });
    }

    camera_obj.drawing.vert_count = object.vertices.items.len;

    const camera_vertex = try graphics.SpatialMesh.Pipeline.vertex_description.createBuffer(gc, object.vertices.items.len);
    try camera_vertex.setVertex(graphics.SpatialMesh.Pipeline.vertex_description, gc, state.main_win.pool, object.vertices.items);
    camera_obj.drawing.vertex_buffer = camera_vertex;

    const camera_index = try graphics.BufferHandle.init(gc, .{ .size = @sizeOf(u32) * object.indices.items.len, .buffer_type = .index });
    try camera_index.setIndices(gc, state.main_win.pool, object.indices.items);
    camera_obj.drawing.index_buffer = camera_index;

    // shadow drawing
    const ShadowPipeline: graphics.PipelineDescription = .{
        .vertex_description = .{
            .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 }, .{ .size = 3 } },
        },
        .render_type = .triangle,
        .depth_test = true,
        .cull_type = .none,
        .bindings = &.{
            .{ .uniform = .{ .size = graphics.GlobalUniform.getSize() } },
            .{ .uniform = .{ .size = graphics.SpatialMesh.Uniform.getSize() } },
        },
        .attachment_descriptions = &.{.{}},
        .constants_size = PushConstants.getSize(),
        .global_ubo = true,
    };
    var shadow_pipeline = try graphics.RenderPipeline.init(ally, .{
        .description = ShadowPipeline,
        .shaders = &.{triangle_vert},
        .render_pass = shadow_pass,
        .gc = &state.main_win.gc,
        .flipped_z = true,
    });
    defer shadow_pipeline.deinit(&state.main_win.gc);

    const shadow_drawing = try ally.create(graphics.Drawing);
    const shadow_mesh = try graphics.SpatialMesh.init(shadow_drawing, state.main_win, .{
        .pos = math.Vec3.init(.{ 0, 0, 0 }),
        .pipeline = shadow_pipeline,
    });

    shadow_mesh.drawing.vert_count = object.vertices.items.len;
    shadow_mesh.drawing.vertex_buffer = camera_vertex;
    shadow_mesh.drawing.index_buffer = camera_index;

    state.key_down = key_down;

    // fps counter

    var fps = try graphics.TextFt.init(ally, .{
        .path = "resources/cmunrm.ttf",
        .size = 50,
        .line_spacing = 1,
        .bounding_width = 250,
        .flip_y = true,
        .scene = &state.scene,
    });
    defer fps.deinit();
    fps.transform.translation = math.Vec2.init(.{ 10, 10 });

    std.debug.print("{any}\n", .{screen_obj.vertices.items});
    try graphics.SpatialMesh.Pipeline.vertex_description.bindVertex(screen.drawing, screen_obj.vertices.items, screen_obj.indices.items);

    while (state.main_win.alive) {
        try state.updateEvents();

        const uniform: graphics.SpatialMesh.Uniform.T = .{
            .spatial_pos = .{ 0, 0, 0 },
        };

        //var spin = math.rotationY(f32, @floatCast(state.time * 5.0));

        (try camera_obj.drawing.getUniformOrCreate(1, 0)).setAsUniform(graphics.SpatialMesh.Uniform, uniform);

        //const first_pos = spin.dot(Vec3.init(.{ 2, 2, 2 }));

        for (lights, 0..) |light, i| {
            const spinned_pos = light.pos;
            const light_matrix = math.orthoMatrix(-5, 5, -5, 5, 1.0, 20.0).mul(
                math.lookAtMatrix(spinned_pos, Vec3.init(.{ 0, 0, 0 }), Vec3.init(.{ 0, 1, 0 })),
            );

            (try camera_obj.drawing.getUniformOrCreate(2, @intCast(i))).setAsUniform(LightArray, .{
                .pos = spinned_pos.val,
                .intensity = light.intensity,
                .matrix = light_matrix,
            });
        }

        try fps.clear();
        try fps.printFmt(ally, "FPS: {}", .{@as(u32, @intFromFloat(1 / state.dt))});

        const frame_id = builder.frame_id;
        const swapchain = &state.main_win.swapchain;
        const extent = swapchain.extent;

        try swapchain.wait(gc, frame_id);

        state.image_index = try swapchain.acquireImage(gc, frame_id);
        try builder.beginCommand(gc);

        // shadow pass
        for (lights) |light| {
            const spinned_pos = light.pos;
            const light_matrix = math.orthoMatrix(-5, 5, -5, 5, 1.0, 20.0).mul(
                math.lookAtMatrix(spinned_pos, Vec3.init(.{ 0, 0, 0 }), Vec3.init(.{ 0, 1, 0 })),
            );
            const data: PushConstants.T = .{
                .cam_pos = Vec3.init(.{ 0, 0, 0 }).val,
                .cam_transform = light_matrix,
                .light_count = lights.len,
            };
            builder.push(PushConstants, gc, pipeline, &data);

            try builder.transitionLayout(gc, light.shadow_tex.image, .{
                .old_layout = .undefined,
                .new_layout = .depth_stencil_attachment_optimal,
            });
            try builder.setViewport(gc, .{ .flip_z = state.scene.flip_z, .width = shadow_res, .height = shadow_res });
            builder.beginRenderPass(gc, light.shadow_pass, light.shadow_buffer, .{
                .x = 0,
                .y = 0,
                .width = shadow_res,
                .height = shadow_res,
            });
            try shadow_drawing.draw(builder.getCurrent(), .{ .frame_id = builder.frame_id, .bind_pipeline = true });
            builder.endRenderPass(gc);
            try builder.transitionLayout(gc, light.shadow_tex.image, .{
                .old_layout = .depth_stencil_attachment_optimal,
                .new_layout = .shader_read_only_optimal,
            });
        }

        const data = .{
            .cam_pos = state.cam.move.val,
            .cam_transform = state.cam.transform_mat,
            .light_count = lights.len,
        };
        builder.push(PushConstants, gc, pipeline, &data);
        // first
        try builder.setViewport(gc, .{ .flip_z = state.scene.flip_z, .width = extent.width, .height = extent.height });
        builder.beginRenderPass(gc, state.first_pass, state.post_buffer, .{
            .x = 0,
            .y = 0,
            .width = extent.width,
            .height = extent.height,
        });
        try state.scene.draw(builder);
        try screen_drawing.draw(builder.getCurrent(), .{ .frame_id = builder.frame_id, .bind_pipeline = true });
        builder.endRenderPass(gc);

        // post
        try builder.setViewport(gc, .{ .flip_z = false, .width = extent.width, .height = extent.height });
        builder.beginRenderPass(gc, state.scene.window.render_pass, state.scene.window.framebuffers[@intFromEnum(state.image_index)], .{
            .x = 0,
            .y = 0,
            .width = extent.width,
            .height = extent.height,
        });
        try state.post_scene.draw(builder);
        builder.endRenderPass(gc);

        try builder.endCommand(gc);
        try state.submit();
    }
}
