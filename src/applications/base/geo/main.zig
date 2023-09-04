const std = @import("std");
const display = @import("display.zig");

const math = @import("math");
const gl = @import("gl");
const common = @import("common");
const numericals = @import("numericals");
const geometry = @import("geometry");
const graphics = @import("graphics");

const Parsing = @import("parsing");

const BdfParse = Parsing.BdfParse;
const ObjParse = graphics.ObjParse;
const VsopParse = Parsing.VsopParse;

var state: *display.State = undefined;

fn key_down(keys: []const bool, mods: i32, dt: f32) !void {
    if (keys[graphics.glfw.GLFW_KEY_Q]) {
        state.main_win.alive = false;
    }

    try state.cam.spatialMove(keys, mods, dt, &state.cam.move, graphics.Camera.DefaultSpatial);
}

pub fn main() !void {
    defer _ = common.gpa_instance.deinit();

    var bdf = try BdfParse.init();
    defer bdf.deinit();
    try bdf.parse("b12.bdf");

    try graphics.initGraphics();
    defer graphics.deinitGraphics();

    state = try display.State.init();
    defer state.deinit();

    gl.cullFace(gl.FRONT);
    gl.enable(gl.BLEND);
    gl.lineWidth(2);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    var text = try graphics.Text.init(
        try state.scene.new(.spatial),
        bdf,
        .{ 0, 0, 0 },
    );
    defer text.deinit();

    try text.initUniform();

    var obj_parser = try ObjParse.init(common.allocator);
    var object = try obj_parser.parse("resources/camera.obj");
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
        try text.printFmt("{d:.4} {d:.1} いいの、吸っちゃっていいの？", .{ state.cam.move, 1 / state.dt });
        try state.render();
    }
}
