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

    var text = try graphics.TextFt.init(ally, .{
        .path = "resources/fonts/Fairfax.ttf",
        .size = 12,
        .line_spacing = 1,
        .bounding_width = 250,
    });
    defer text.deinit(ally);

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

    var pipeline = try graphics.RenderPipeline.init(ally, .{
        .description = graphics.SpatialPipeline,
        .shaders = &.{ triangle_vert, triangle_frag },
        .render_pass = state.first_pass,
        .gc = &state.main_win.gc,
        .flipped_z = true,
    });
    defer pipeline.deinit(&state.main_win.gc);

    const camera_obj = try graphics.SpatialMesh.init(&state.scene, .{
        .pos = .{ 0, 0, 0 },
        .pipeline = pipeline,
    });

    try graphics.SpatialPipeline.vertex_description.bindVertex(camera_obj.drawing, object.vertices.items, object.indices.items);

    state.key_down = key_down;

    while (state.main_win.alive) {
        try state.updateEvents();
        try camera_obj.linkCamera(state.cam);
        //try text.printFmt(&state.scene, ally, "{d:.4} {d:.1}", .{ state.cam.move, 1 / state.dt });
        try state.render();
    }
}
