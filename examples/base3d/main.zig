const std = @import("std");

const ui = @import("ui");
const graphics = ui.graphics;
const Vec3 = ui.Vec3;
const Vertex = ui.Vertex;
const common = ui.common;

const display = ui.display;

const math = ui.math;
const gl = ui.gl;

var state: *display.State = undefined;

fn key_down(keys: []const bool, mods: i32, dt: f32) !void {
    if (keys[graphics.glfw.GLFW_KEY_Q]) {
        state.main_win.alive = false;
    }

    try state.cam.spatialMove(keys, mods, dt, &state.cam.move, graphics.elems.Camera.DefaultSpatial);
}

pub fn main() !void {
    defer _ = common.gpa_instance.deinit();

    var bdf = try ui.parsing.BdfParse.init();
    defer bdf.deinit();
    try bdf.parse("b12.bdf");

    state = try display.State.init();
    defer state.deinit();

    var text = try graphics.elems.Text.init(
        try state.scene.new(.spatial),
        bdf,
        .{ 0, 0, 0 },
    );
    defer text.deinit();

    try text.initUniform();

    // get obj file
    var arg_it = std.process.args();
    _ = arg_it.next();

    var obj_file = arg_it.next() orelse return error.NotEnoughArguments;

    var obj_parser = try ui.graphics.ObjParse.init(common.allocator);
    var object = try obj_parser.parse(obj_file);
    defer object.deinit();

    var camera_obj = try graphics.SpatialMesh.init(
        try state.scene.new(.spatial),
        .{ 0, 0, 0 },
        try graphics.Shader.setupShader(
            @embedFile("shaders/triangle/vertex.glsl"),
            @embedFile("shaders/triangle/fragment.glsl"),
        ),
    );

    camera_obj.drawing.bindVertex(object.vertices.items, object.indices.items);

    try state.cam.linkDrawing(camera_obj.drawing);
    try camera_obj.initUniform();

    state.key_down = key_down;

    while (state.main_win.alive) {
        try state.updateEvents();
        try text.printFmt("{d:.4} {d:.1}", .{ state.cam.move, 1 / state.dt });
        try state.render();
    }
}
