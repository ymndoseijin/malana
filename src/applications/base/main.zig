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

fn frameFunc(win: *graphics.Window, width: i32, height: i32) !void {
    _ = win;
    const w: f32 = @floatFromInt(width);
    const h: f32 = @floatFromInt(height);
    try state.cam.setParameters(0.6, w / h, 0.1, 2048);
}

var is_wireframe = false;

fn keyFunc(win: *graphics.Window, key: i32, scancode: i32, action: i32, mods: i32) !void {
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

fn key_down(keys: []bool, mods: i32, dt: f32) !void {
    if (keys[glfw.GLFW_KEY_Q]) {
        state.main_win.alive = false;
    }

    try state.cam.spatialMove(keys, mods, dt, &state.cam.move, Camera.DefaultSpatial);
}

fn makeAxis() !void {
    var line = try Line.init(
        try state.scene.new(.line),
        &[_]Vec3{ .{ 0, 0.01, 0 }, .{ 2, 0, 0 } },
        &[_]Vec3{ .{ 1, 0, 0 }, .{ 1, 0, 0 } },
        try graphics.Shader.setupShader(@embedFile("shaders/line/vertex.glsl"), @embedFile("shaders/line/fragment.glsl")),
    );
    line.drawing.setUniformFloat("fog", &state.fog);
    try state.cam.linkDrawing(line.drawing);
    try line.drawing.addUniformVec3("real_cam.move", &state.cam.move);

    line = try Line.init(
        try state.scene.new(.line),
        &[_]Vec3{ .{ 0, 0.01, 0 }, .{ 0, 2, 0 } },
        &[_]Vec3{ .{ 0, 1, 0 }, .{ 0, 1, 0 } },
        try graphics.Shader.setupShader(@embedFile("shaders/line/vertex.glsl"), @embedFile("shaders/line/fragment.glsl")),
    );
    line.drawing.setUniformFloat("fog", &state.fog);
    try state.cam.linkDrawing(line.drawing);
    try line.drawing.addUniformVec3("real_cam.move", &state.cam.move);

    line = try Line.init(
        try state.scene.new(.line),
        &[_]Vec3{ .{ 0, 0.01, 0 }, .{ 0, 0, 2 } },
        &[_]Vec3{ .{ 0, 0, 1 }, .{ 0, 0, 1 } },
        try graphics.Shader.setupShader(@embedFile("shaders/line/vertex.glsl"), @embedFile("shaders/line/fragment.glsl")),
    );
    try state.cam.linkDrawing(line.drawing);
    try line.drawing.addUniformVec3("real_cam.move", &state.cam.move);
    line.drawing.setUniformFloat("fog", &state.fog);
}

fn makeGrid() !void {
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

const Pixel = struct { r: u8, g: u8, b: u8, a: u8 };

const ImageTexture = struct {
    data: []Pixel,
    width: usize,
    height: usize,

    pub fn get(self: ImageTexture, x: usize, y: usize) Pixel {
        return self.data[self.width * y + x];
    }

    pub fn set(self: *ImageTexture, x: usize, y: usize, pix: Pixel) void {
        self.data[self.width * y + x] = pix;
    }
};

const Cubemap = struct {
    faces: [6]ImageTexture,
    pub fn deinit(self: *Cubemap) void {
        for (self.faces) |face| {
            common.allocator.free(face.data);
        }
    }
};

fn processImage() !Cubemap {
    var read_image = try img.Image.fromFilePath(common.allocator, "resources/ear.qoi");
    defer read_image.deinit();

    var arr: []img.color.Rgba32 = undefined;
    switch (read_image.pixels) {
        .rgba32 => |data| {
            arr = data;
        },
        else => return error.InvalidImage,
    }

    const square_width = 500;

    var res: Cubemap = undefined;

    var og = ImageTexture{
        .data = try common.allocator.alloc(Pixel, arr.len),
        .width = read_image.width,
        .height = read_image.height,
    };
    defer common.allocator.free(og.data);

    for (arr, 0..) |pix, i| {
        og.data[i].r = pix.r;
        og.data[i].g = pix.g;
        og.data[i].b = pix.b;
        og.data[i].a = pix.a;
    }

    for (0..6) |face_idx| {
        var face_img = ImageTexture{
            .data = try common.allocator.alloc(Pixel, square_width * square_width),
            .width = square_width,
            .height = square_width,
        };
        for (0..face_img.width) |x_int| {
            for (0..face_img.height) |y_int| {
                var plane_x: f64 = @floatFromInt(x_int);
                plane_x /= @floatFromInt(face_img.width);
                plane_x *= 2;
                plane_x -= 1;
                var plane_y: f64 = @floatFromInt(y_int);
                plane_y /= @floatFromInt(face_img.height);
                plane_y *= 2;
                plane_y -= 1;

                //plane_x *= -1;
                //plane_y *= -1;

                const x: f64 = switch (face_idx) {
                    0 => -1.0,
                    1 => -plane_x,
                    2 => plane_x,
                    3 => 1.0,
                    4 => -plane_x,
                    5 => -plane_x,
                    else => unreachable,
                };
                const z: f64 = switch (face_idx) {
                    0 => -plane_y,
                    1 => 1.0,
                    2 => -plane_y,
                    3 => -plane_y,
                    4 => -1.0,
                    5 => -plane_y,
                    else => unreachable,
                };
                const y: f64 = switch (face_idx) {
                    0 => -plane_x,
                    1 => plane_y,
                    2 => -1.0,
                    3 => plane_x,
                    4 => -plane_y,
                    5 => 1.0,
                    else => unreachable,
                };

                const r = @sqrt(x * x + y * y + z * z);

                const w_s: f64 = @floatFromInt(og.width);
                const h_s: f64 = @floatFromInt(og.height);

                const x_f = std.math.atan2(f64, y, x) / TAU;
                const y_f = std.math.acos(z / r) / TAU * 2;

                const x_s: usize = @intFromFloat(@mod(x_f, 1) * w_s);
                const y_s: usize = @intFromFloat(@mod(y_f, 1) * h_s);

                face_img.set(x_int, y_int, og.get(x_s, y_s));
            }
        }
        res.faces[face_idx] = face_img;
    }

    return res;
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

    var timer: f32 = 0;

    var camera_obj = try graphics.SpatialMesh.init(
        try state.scene.new(.spatial),
        .{ 0, 0, 0 },
        try graphics.Shader.setupShader(
            @embedFile("shaders/image/vertex.glsl"),
            @embedFile("shaders/image/fragment.glsl"),
        ),
    );

    try state.cam.linkDrawing(camera_obj.drawing);

    try camera_obj.initUniform();
    try camera_obj.drawing.addUniformFloat("fog", &state.fog);

    camera_obj.drawing.bindVertex(&graphics.Square.vertices, &graphics.Square.indices);

    var res = try processImage();
    defer res.deinit();
    //defer common.allocator.free(res.data);

    var width: f32 = @floatFromInt(res.faces[0].width);
    var height: f32 = @floatFromInt(res.faces[0].height);

    //var affine = math.Mat3.scaling(.{ width, height, 100 });
    var size = Vec3{ width, height, 0 };
    camera_obj.drawing.setUniformVec3("size", &size);

    var idx: usize = 5;
    try camera_obj.drawing.textureFromRgba(res.faces[idx].data, res.faces[idx].width, res.faces[idx].height);
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

        if (timer > 1.0) {
            try text.printFmt("cam: {d:.4} {d:.4} {d:.4}\n", .{ state.cam.eye, state.cam.move, 1 / dt });

            //idx += 1;
            idx %= 6;
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
