const std = @import("std");
const math = @import("math");
const gl = @import("gl");
const numericals = @import("numericals");
const img = @import("img");
const geometry = @import("geometry");
const graphics = @import("graphics");
const common = @import("common");
const Parsing = @import("parsing");

const BdfParse = Parsing.BdfParse;
const ObjParse = graphics.ObjParse;
const VsopParse = Parsing.VsopParse;

const Mesh = geometry.Mesh;
const Vertex = geometry.Vertex;
const HalfEdge = geometry.HalfEdge;

const Drawing = graphics.Drawing;
const glfw = graphics.glfw;

const Camera = graphics.Camera;
const Cube = graphics.Cube;
const Line = graphics.Line;
const MeshBuilder = graphics.MeshBuilder;

const Mat4 = math.Mat4;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Vec3Utils = math.Vec3Utils;

const SpatialPipeline = graphics.SpatialPipeline;

var current_keys: [glfw.GLFW_KEY_MENU + 1]bool = .{false} ** (glfw.GLFW_KEY_MENU + 1);
var down_num: usize = 0;
var last_mods: i32 = 0;

const DrawingList = union(enum) {
    line: *Drawing(graphics.LinePipeline),
    spatial: *Drawing(graphics.SpatialPipeline),
};

pub const State = struct {
    main_win: *graphics.Window,
    scene: graphics.Scene(DrawingList),
    skybox_scene: graphics.Scene(DrawingList),

    cam: Camera,
    cam_pos: Vec3,

    fog: f32,

    time: f64,
    pub fn init() !State {
        var main_win = try graphics.Window.init(100, 100);

        main_win.setKeyCallback(keyFunc);
        main_win.setFrameCallback(frameFunc);

        var cam = try Camera.init(0.6, 1, 0.1, 2048);
        cam.move = .{ 0, 0, 0 };
        try cam.updateMat();

        const now: f64 = @floatFromInt(std.time.timestamp());

        return State{
            .main_win = main_win,
            .cam = cam,
            .cam_pos = .{ 7, 3.8, 13.7 },
            .fog = 2,
            .time = now / 86400.0 + 2440587.5,
            .scene = try graphics.Scene(DrawingList).init(),
            .skybox_scene = try graphics.Scene(DrawingList).init(),
        };
    }

    pub fn deinit(self: *State) void {
        self.main_win.deinit();
        self.scene.deinit();
        self.skybox_scene.deinit();
    }
};

var state: State = undefined;

pub fn frameFunc(win: *graphics.Window, width: i32, height: i32) !void {
    _ = win;
    const w: f32 = @floatFromInt(width);
    const h: f32 = @floatFromInt(height);
    try state.cam.setParameters(0.6, w / h, 0.1, 2048);
}

var is_wireframe = false;

pub fn keyFunc(win: *graphics.Window, key: i32, scancode: i32, action: i32, mods: i32) !void {
    _ = win;
    _ = scancode;

    if (action == glfw.GLFW_PRESS) {
        if (key == glfw.GLFW_KEY_C) {
            if (is_wireframe) {
                gl.polygonMode(gl.FRONT_AND_BACK, gl.FILL);
                is_wireframe = false;
            } else {
                gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
                is_wireframe = true;
            }
        }
        current_keys[@intCast(key)] = true;
        last_mods = mods;
        down_num += 1;
    } else if (action == glfw.GLFW_RELEASE) {
        current_keys[@intCast(key)] = false;
        down_num -= 1;
    }
}

const TAU = 6.28318530718;

pub fn key_down(keys: []bool, mods: i32, dt: f32) !void {
    if (keys[glfw.GLFW_KEY_Q]) {
        state.main_win.alive = false;
    }

    try state.cam.spatialMove(keys, mods, dt, &state.cam_pos, Camera.DefaultSpatial);
}

pub fn makeAxis() !void {
    var line = try Line.init(
        try state.scene.new(.line),
        &[_]Vec3{ .{ 0, 0.01, 0 }, .{ 2, 0, 0 } },
        &[_]Vec3{ .{ 1, 0, 0 }, .{ 1, 0, 0 } },
        try graphics.Shader.setupShader(@embedFile("shaders/line/vertex.glsl"), @embedFile("shaders/line/fragment.glsl")),
    );
    line.drawing.setUniformFloat("fog", &state.fog);
    try state.cam.linkDrawing(line.drawing);
    try line.drawing.addUniformVec3("real_cam_pos", &state.cam_pos);

    line = try Line.init(
        try state.scene.new(.line),
        &[_]Vec3{ .{ 0, 0.01, 0 }, .{ 0, 2, 0 } },
        &[_]Vec3{ .{ 0, 1, 0 }, .{ 0, 1, 0 } },
        try graphics.Shader.setupShader(@embedFile("shaders/line/vertex.glsl"), @embedFile("shaders/line/fragment.glsl")),
    );
    line.drawing.setUniformFloat("fog", &state.fog);
    try state.cam.linkDrawing(line.drawing);
    try line.drawing.addUniformVec3("real_cam_pos", &state.cam_pos);

    line = try Line.init(
        try state.scene.new(.line),
        &[_]Vec3{ .{ 0, 0.01, 0 }, .{ 0, 0, 2 } },
        &[_]Vec3{ .{ 0, 0, 1 }, .{ 0, 0, 1 } },
        try graphics.Shader.setupShader(@embedFile("shaders/line/vertex.glsl"), @embedFile("shaders/line/fragment.glsl")),
    );
    try state.cam.linkDrawing(line.drawing);
    try line.drawing.addUniformVec3("real_cam_pos", &state.cam_pos);
    line.drawing.setUniformFloat("fog", &state.fog);
}

pub fn makeGrid() !void {
    const size = 100;
    for (0..size) |i| {
        var x: f32 = @floatFromInt(i);
        x -= size / 2;

        var line = try Line.init(
            try state.scene.new(.line),
            &[_]Vec3{ .{ x, 0, -size / 2 }, .{ x, 0, size / 2 } },
            &[_]Vec3{ .{ 0.5, 0.5, 0.5 }, .{ 0.5, 0.5, 0.5 } },
        );

        try state.cam.linkDrawing(line.drawing);
        line.drawing.setUniformFloat("fog", &state.fog);

        line = try Line.init(
            try state.scene.new(.line),
            &[_]Vec3{ .{ -size / 2, 0, x }, .{ size / 2, 0, x } },
            &[_]Vec3{ .{ 0.5, 0.5, 0.5 }, .{ 0.5, 0.5, 0.5 } },
        );

        try state.cam.linkDrawing(line.drawing);
        line.drawing.setUniformFloat("fog", &state.fog);
    }
}

const fs = 15;

pub fn toMesh(half: *HalfEdge) !graphics.MeshBuilder {
    var builder = try graphics.MeshBuilder.init();

    var set = std.AutoHashMap(*HalfEdge, void).init(common.allocator);
    var stack = std.ArrayList(?*HalfEdge).init(common.allocator);

    defer set.deinit();
    defer stack.deinit();

    try stack.append(half);

    while (stack.items.len > 0) {
        var edge_or = stack.pop();
        if (edge_or) |edge| {
            if (set.get(edge)) |_| continue;
            try set.put(edge, void{});

            var v = edge.face.vertices;

            var a = v[0].*;
            var b = v[1].*;
            var c = v[2].*;

            try builder.addTri(.{ a, b, c });

            if (edge.next) |_| {
                if (edge.twin) |twin| {
                    try stack.append(twin);
                }
            }
            try stack.append(edge.next);
        }
    }

    return builder;
}

pub fn bdfToRgba(bdf: *BdfParse, c: u8) ![fs * fs]img.color.Rgba32 {
    var buf: [fs * fs]img.color.Rgba32 = undefined;
    var res = try bdf.getChar(c);
    for (res, 0..) |val, i| {
        if (val) {
            buf[i] = .{ .r = 255, .g = 255, .b = 255, .a = 255 };
        } else {
            buf[i] = .{ .r = 30, .g = 100, .b = 100, .a = 255 };
        }
    }
    return buf;
}

pub fn makeSphere() !Mesh {
    var mesh = Mesh.init(common.allocator);

    var obj_parser = try ObjParse.init(common.allocator);
    var obj_builder = try obj_parser.parse("resources/cube.obj");
    defer obj_builder.deinit();

    try mesh.makeFrom(obj_builder.vertices.items, obj_builder.indices.items, .{
        .pos_offset = 0,
        .uv_offset = 3,
        .norm_offset = 5,
        .length = 8,
    }, 3);

    try mesh.subdivideMesh(5);

    var set = std.AutoHashMap(*HalfEdge, void).init(common.allocator);
    var stack = std.ArrayList(?*HalfEdge).init(common.allocator);

    defer set.deinit();
    defer stack.deinit();

    try stack.append(mesh.first_half);

    while (stack.items.len > 0) {
        var edge_or = stack.pop();
        if (edge_or) |edge| {
            if (set.get(edge)) |_| continue;
            try set.put(edge, void{});

            var position = &edge.vertex.pos;

            position.* /= @splat(@sqrt(@reduce(.Add, position.* * position.*)));

            if (edge.next) |_| {
                if (edge.twin) |twin| {
                    try stack.append(twin);
                }
            }
            try stack.append(edge.next);
        }
    }

    try mesh.fixNormals();

    return mesh;
}

pub fn main() !void {
    defer _ = common.gpa_instance.deinit();

    var bdf = try BdfParse.init();
    defer bdf.deinit();
    try bdf.parse("b12.bdf");

    try graphics.initGraphics();
    defer graphics.deinitGraphics();

    state = try State.init();
    defer state.deinit();

    gl.cullFace(gl.FRONT);
    gl.enable(gl.BLEND);
    gl.lineWidth(2);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    var text = try graphics.Text.init(
        try state.scene.new(.spatial),
        bdf,
        .{ 0, 1, 0 },
    );
    try text.initUniform();
    defer text.deinit();

    try makeAxis();
    //try makeGrid();

    var last_time: f32 = 0;

    var sphere = try makeSphere();
    var builder = try toMesh(sphere.first_half.?);
    defer sphere.deinit();
    defer builder.deinit();

    var timer: f32 = 0;

    var camera_obj = try builder.toSpatial(
        try state.scene.new(.spatial),
        .{
            .vert = @embedFile("shaders/triangle/vertex.glsl"),
            .frag = @embedFile("shaders/triangle/fragment.glsl"),
            .pos = .{ 0, 0, 0 },
        },
    );

    try state.cam.linkDrawing(camera_obj.drawing);

    try camera_obj.initUniform();
    try camera_obj.drawing.addUniformVec3("real_cam_pos", &state.cam_pos);
    try camera_obj.drawing.addUniformFloat("fog", &state.fog);

    camera_obj.drawing.bindVertex(builder.vertices.items, builder.indices.items);
    try camera_obj.drawing.textureFromPath("resources/table.png");

    while (state.main_win.alive) {
        graphics.waitGraphicsEvent();

        gl.clearColor(0.0, 0.0, 0.0, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const time = @as(f32, @floatCast(glfw.glfwGetTime()));

        const dt = time - last_time;
        //state.time += dt * 5;

        if (down_num > 0) {
            try key_down(&current_keys, last_mods, dt);
        }
        state.cam.eye = state.cam.eye;
        try state.cam.updateMat();

        timer += dt;

        if (timer > 0.025) {
            try text.printFmt("cam: {d:.4} {d:.4} {d:.4}\n", .{ state.cam.eye, state.cam.move, 1 / dt });
            timer = 0;
        }

        gl.disable(gl.DEPTH_TEST);
        gl.disable(gl.CULL_FACE);
        try state.skybox_scene.draw(state.main_win.*);

        gl.enable(gl.DEPTH_TEST);
        gl.enable(gl.CULL_FACE);
        gl.cullFace(gl.BACK);
        try state.scene.draw(state.main_win.*);

        last_time = time;

        graphics.glfw.glfwSwapBuffers(state.main_win.glfw_win);
    }
}
