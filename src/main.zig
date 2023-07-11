const std = @import("std");
const math = @import("math.zig");
const gl = @import("gl.zig");
const img = @import("img");
const graphics = @import("graphics.zig");
const common = @import("common.zig");

const BdfParse = @import("bdf.zig").BdfParse;

const Drawing = graphics.Drawing;
const glfw = graphics.glfw;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec3Utils = math.Vec3Utils;

var current_keys: [glfw.GLFW_KEY_MENU + 1]bool = .{false} ** (glfw.GLFW_KEY_MENU + 1);
var down_num: usize = 0;
var last_mods: i32 = 0;

var main_win: *graphics.Window = undefined;
var scene: graphics.Scene = undefined;

const Camera = struct {
    perspective_mat: math.Mat4,

    transform_mat: math.Mat4,

    move: @Vector(3, f32) = .{ 7, 3.8, 13.7 },
    up: @Vector(3, f32) = .{ 0, 1, 0 },

    eye: [2]f32 = .{ 4.32, -0.23 },

    pub fn updateMat(self: *Camera) !void {
        const eye_x = self.eye[0];
        const eye_y = self.eye[1];

        const eye = Vec3{ std.math.cos(eye_x) * std.math.cos(eye_y), std.math.sin(eye_y), std.math.sin(eye_x) * std.math.cos(eye_y) };

        const view_mat = math.lookAtMatrix(.{ 0, 0, 0 }, eye, self.up);
        const translation_mat = Mat4.translation(-self.move);

        self.transform_mat = translation_mat.mul(Mat4, view_mat.mul(Mat4, self.perspective_mat));

        std.debug.print("cam: {d:.4} {d:.4}\n", .{ self.eye, self.move });
    }

    pub fn setParameters(self: *Camera, fovy: f32, aspect: f32, nearZ: f32, farZ: f32) !void {
        self.perspective_mat = math.perspectiveMatrix(fovy, aspect, nearZ, farZ);
        try self.updateMat();
    }

    pub fn init(fovy: f32, aspect: f32, nearZ: f32, farZ: f32) !Camera {
        var init_cam = Camera{
            .transform_mat = undefined,
            .perspective_mat = math.perspectiveMatrix(fovy, aspect, nearZ, farZ),
        };

        try init_cam.updateMat();

        return init_cam;
    }
};

var cam: Camera = undefined;

pub fn frameFunc(win: *graphics.Window, width: i32, height: i32) !void {
    _ = win;
    const w: f32 = @floatFromInt(width);
    const h: f32 = @floatFromInt(height);
    try cam.setParameters(0.6, w / h, 0.1, 2048);
}

pub fn keyFunc(win: *graphics.Window, key: i32, scancode: i32, action: i32, mods: i32) !void {
    _ = win;
    _ = scancode;

    if (action == glfw.GLFW_PRESS) {
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
    _ = mods;

    var look_speed: f32 = 1 * dt;
    var speed: f32 = 2;

    const eye_x = cam.eye[0];
    const eye_y = cam.eye[1];

    if (keys[glfw.GLFW_KEY_LEFT_SHIFT]) {
        speed *= 7;
        look_speed *= 2;
    }

    std.debug.print("{d:.4} {d:.4}\n", .{ speed, look_speed });

    const eye = @splat(3, speed * dt) * Vec3{ std.math.cos(eye_x) * std.math.cos(eye_y), std.math.sin(eye_y), std.math.sin(eye_x) * std.math.cos(eye_y) };

    const cross_eye = @splat(3, speed * dt) * -Vec3Utils.crossn(eye, cam.up);

    const up_eye = @splat(3, speed * dt) * Vec3Utils.crossn(eye, cross_eye);

    if (keys[glfw.GLFW_KEY_Q]) {
        main_win.alive = false;
    }

    if (keys[glfw.GLFW_KEY_W]) {
        cam.move += eye;
    }

    if (keys[glfw.GLFW_KEY_S]) {
        cam.move -= eye;
    }

    if (keys[glfw.GLFW_KEY_A]) {
        cam.move += cross_eye;
    }

    if (keys[glfw.GLFW_KEY_D]) {
        cam.move -= cross_eye;
    }

    if (keys[glfw.GLFW_KEY_R]) {
        cam.move += up_eye;
    }

    if (keys[glfw.GLFW_KEY_F]) {
        cam.move -= up_eye;
    }

    if (keys[graphics.glfw.GLFW_KEY_L]) {
        cam.eye[0] += look_speed;
    }

    if (keys[graphics.glfw.GLFW_KEY_H]) {
        cam.eye[0] -= look_speed;
    }

    if (keys[graphics.glfw.GLFW_KEY_K]) {
        if (cam.eye[1] < TAU) cam.eye[1] += look_speed;
    }

    if (keys[graphics.glfw.GLFW_KEY_J]) {
        if (cam.eye[1] > -TAU) cam.eye[1] -= look_speed;
    }

    try cam.updateMat();
}

const Line = struct {
    pub fn init(a: Vec3, b: Vec3, c: Vec3) !Line {
        var shader = try graphics.Shader.setupShader("shaders/line/vertex.glsl", "shaders/line/fragment.glsl");
        var drawing = graphics.Drawing(.line).init(shader);

        const vertices = [_]f32{
            a[0], a[1], a[2], c[0], c[1], c[2],
            b[0], b[1], b[2], c[0], c[1], c[2],
        };
        const indices = [_]u32{ 0, 1 };

        drawing.bindVertex(&vertices, &indices);
        try drawing.uniform4fv_array.append(.{ .name = "transform", .value = &cam.transform_mat.rows[0][0] });

        return Line{
            .vertices = vertices,
            .indices = indices,
            .drawing = drawing,
        };
    }
    vertices: [12]f32,
    indices: [2]u32,
    drawing: Drawing(.line),
};

const Cube = struct {
    // zig fmt: off
    pub const vertices = [_]f32{
        1, 1, 0, 0, 1, 0, 0, -1,
        0, 0, 0, 1, 0, 0, 0, -1,
        1, 0, 0, 0, 0, 0, 0, -1,
        0, 1, 0, 1, 1, 0, 0, -1,

        1, 1, 1, 0, 1, 1, 0, 0,
        1, 0, 0, 1, 0, 1, 0, 0,
        1, 0, 1, 0, 0, 1, 0, 0,
        1, 1, 0, 1, 1, 1, 0, 0,

        0, 1, 1, 0, 1, 0, 0, 1,
        1, 0, 1, 1, 0, 0, 0, 1,
        0, 0, 1, 0, 0, 0, 0, 1,
        1, 1, 1, 1, 1, 0, 0, 1,

        0, 1, 0, 0, 1, -1, 0, 0,
        0, 0, 1, 1, 0, -1, 0, 0,
        0, 0, 0, 0, 0, -1, 0, 0,
        0, 1, 1, 1, 1, -1, 0, 0,

        0, 1, 0, 0, 1, 0, 1, 0,
        1, 1, 1, 1, 0, 0, 1, 0,
        0, 1, 1, 0, 0, 0, 1, 0,
        1, 1, 0, 1, 1, 0, 1, 0,

        0, 0, 1, 0, 1, 0, -1, 0,
        1, 0, 0, 1, 0, 0, -1, 0,
        0, 0, 0, 0, 0, 0, -1, 0,
        1, 0, 1, 1, 1, 0, -1, 0,
    };
    // zig fmt: on

    pub fn getIndices() [6 * vertices.len]u32 {
        var temp_indices: [6 * vertices.len]u32 = undefined;
        inline for (0..Cube.vertices.len) |i| {
            temp_indices[6 * i] = 4 * i;
            temp_indices[6 * i + 1] = 4 * i + 1;
            temp_indices[6 * i + 2] = 4 * i + 2;
            temp_indices[6 * i + 3] = 4 * i + 3;
            temp_indices[6 * i + 4] = 4 * i + 1;
            temp_indices[6 * i + 5] = 4 * i;
        }

        return temp_indices;
    }

    pub var indices: [6 * vertices.len]u32 = getIndices();

    drawing: Drawing(.spatial),

    pub fn updatePos(self: *Cube, pos: Vec3) void {
        self.drawing.uniform3f_array[0].value = pos;
    }

    pub fn init(pos: Vec3) !Cube {
        var shader = try graphics.Shader.setupShader("shaders/cube/vertex.glsl", "shaders/cube/fragment.glsl");
        var drawing = graphics.Drawing(.spatial).init(shader);

        drawing.bindVertex(&vertices, &indices);

        //try drawing.textureFromPath(texture);
        try drawing.uniform4fv_array.append(.{ .name = "transform", .value = &cam.transform_mat.rows[0][0] });
        try drawing.uniform3f_array.append(.{ .name = "pos", .value = pos });

        return Cube{ .drawing = drawing };
    }
};

pub fn makeAxis() !void {
    var line = try Line.init(.{ 0, 0.01, 0 }, .{ 2, 0, 0 }, .{ 1, 0, 0 });
    try scene.append(.line, line.drawing);

    line = try Line.init(.{ 0, 0.01, 0 }, .{ 0, 2, 0 }, .{ 0, 1, 0 });
    try scene.append(.line, line.drawing);

    line = try Line.init(.{ 0, 0.01, 0 }, .{ 0, 0, 2 }, .{ 0, 0, 1 });
    try scene.append(.line, line.drawing);
}

pub fn makeGrid() !void {
    const size = 100;
    for (0..size) |i| {
        var x: f32 = @floatFromInt(i);
        x -= size / 2;

        var line = try Line.init(.{ x, 0, -size / 2 }, .{ x, 0, size / 2 }, .{ 0.5, 0.5, 0.5 });
        try scene.append(.line, line.drawing);
        line = try Line.init(.{ -size / 2, 0, x }, .{ size / 2, 0, x }, .{ 0.5, 0.5, 0.5 });
        try scene.append(.line, line.drawing);
    }
}

pub fn bdfToRgba(bdf: *BdfParse, c: u8) ![12 * 12]img.color.Rgba32 {
    var buf: [12 * 12]img.color.Rgba32 = undefined;
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

pub fn main() !void {
    defer _ = common.gpa_instance.deinit();

    var bdf = try BdfParse.init();
    try bdf.parse("b12.bdf");

    try graphics.initGraphics();
    defer graphics.deinitGraphics();
    main_win = try graphics.Window.init(100, 100);
    defer main_win.deinit();

    gl.enable(gl.DEPTH_TEST);
    gl.enable(gl.CULL_FACE);
    gl.cullFace(gl.FRONT);

    main_win.setKeyCallback(keyFunc);
    main_win.setFrameCallback(frameFunc);

    cam = try Camera.init(0.6, 1, 0.1, 2048);

    scene = try graphics.Scene.init();
    defer scene.deinit();

    for ("*hello!", 0..) |c, i| {
        var cube = try Cube.init(.{ 10, 0, @as(f32, @floatFromInt(i)) });

        var rgba = try bdfToRgba(&bdf, c);

        try cube.drawing.textureFromRgba(&rgba, 12, 12);
        try scene.append(.spatial, cube.drawing);
    }

    try makeAxis();
    try makeGrid();

    var last_time: f32 = 0;

    while (main_win.alive) {
        graphics.waitGraphicsEvent();

        gl.clearColor(0.2, 0.2, 0.2, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const time = @as(f32, @floatCast(glfw.glfwGetTime()));

        if (down_num > 0) {
            try key_down(&current_keys, last_mods, time - last_time);
        }

        try scene.draw(main_win.*);

        last_time = time;

        graphics.glfw.glfwSwapBuffers(main_win.glfw_win);
    }
}
