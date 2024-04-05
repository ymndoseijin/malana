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
    var object = try obj_parser.parse(obj_file);
    defer object.deinit();

    const triangle_vert = try graphics.Shader.init(state.main_win.gc, &shaders.vert, .vertex);
    defer triangle_vert.deinit(state.main_win.gc);
    const triangle_frag = try graphics.Shader.init(state.main_win.gc, &shaders.frag, .fragment);
    defer triangle_frag.deinit(state.main_win.gc);

    const PushConstants: graphics.DataDescription = .{ .T = extern struct { cam_pos: [3]f32 align(4 * 4), cam_transform: math.Mat4 align(4 * 4) } };

    const TrianglePipeline: graphics.PipelineDescription = .{
        .vertex_description = .{
            .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 }, .{ .size = 3 } },
        },
        .render_type = .triangle,
        .depth_test = true,
        .cull_type = .back,
        .uniform_descriptions = &.{ .{
            .size = graphics.GlobalUniform.getSize(),
            .idx = 0,
        }, .{
            .size = graphics.SpatialMesh.Uniform.getSize(),
            .idx = 1,
        } },
        .constants_size = PushConstants.getSize(),
        .global_ubo = true,
        .sampler_descriptions = &.{.{
            .idx = 2,
            .boundless = true,
        }},
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

    const camera_obj = try graphics.SpatialMesh.init(&state.scene, .{
        .pos = math.Vec3.init(.{ 0, 0, 0 }),
        .pipeline = pipeline,
    });
    try camera_obj.drawing.updateDescriptorSets(ally, .{ .samplers = &.{.{ .idx = 2, .textures = &.{ cubemap, other } }} });

    try graphics.SpatialMesh.Pipeline.vertex_description.bindVertex(camera_obj.drawing, object.vertices.items, object.indices.items);

    state.key_down = key_down;

    var fps = try graphics.TextFt.init(ally, .{ .path = "resources/cmunrm.ttf", .size = 50, .line_spacing = 1, .bounding_width = 250 });
    defer fps.deinit(ally, &state.post_scene);
    fps.transform.translation = math.Vec2.init(.{ 10, 10 });

    while (state.main_win.alive) {
        try state.updateEvents();

        var uniform: graphics.SpatialMesh.Uniform.T = .{
            .spatial_pos = .{ 0, 0, 0 },
            .light_count = 1,
            .lights = undefined,
        };

        const exp = 30;

        uniform.lights[0] = .{
            .pos = .{ 1, 10, 2 },
            .intensity = .{ exp, exp, exp },
        };

        camera_obj.drawing.getUniformOr(1, 0).?.setAsUniform(graphics.SpatialMesh.Uniform, uniform);

        const frame_id = builder.frame_id;
        const swapchain = &state.main_win.swapchain;
        const extent = swapchain.extent;

        try swapchain.wait(gc, frame_id);

        state.image_index = try swapchain.acquireImage(gc, frame_id);
        try builder.beginCommand(gc);

        const data: PushConstants.T = .{ .cam_pos = state.cam.move.val, .cam_transform = state.cam.transform_mat };
        builder.push(PushConstants, gc, pipeline, &data);

        try builder.setViewport(gc, .{ .flip_z = state.scene.flip_z, .width = extent.width, .height = extent.height });
        builder.beginRenderPass(gc, state.first_pass, state.post_buffer, .{
            .x = 0,
            .y = 0,
            .width = extent.width,
            .height = extent.height,
        });
        try state.scene.draw(builder);
        builder.endRenderPass(gc);

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
