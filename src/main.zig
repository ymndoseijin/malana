const std = @import("std");

const graphics = @import("graphics.zig");

const Drawing = graphics.Drawing;

const glfw = @import("graphics.zig").glfw;

const math = @import("math.zig");

const gl = @import("gl.zig");

var current_keys: [glfw.GLFW_KEY_MENU + 1]bool = .{false} ** (glfw.GLFW_KEY_MENU + 1);
var down_num: usize = 0;
var last_mods: i32 = 0;

const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec3Utils = math.Vec3Utils;

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

    var look_speed: f32 = 0.01;
    var speed: f32 = 0.01;

    const eye_x = cam.eye[0];
    const eye_y = cam.eye[1];

    if (keys[glfw.GLFW_KEY_LEFT_SHIFT]) {
        speed *= 7;
        look_speed *= 2;
    }

    const eye = @splat(3, speed * dt) * Vec3{ std.math.cos(eye_x) * std.math.cos(eye_y), std.math.sin(eye_y), std.math.sin(eye_x) * std.math.cos(eye_y) };

    const cross_eye = @splat(3, speed * dt) * -Vec3Utils.crossn(eye, cam.up);

    const up_eye = @splat(3, speed * dt) * Vec3Utils.crossn(eye, cross_eye);

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

    pub fn init() !Cube {
        var shader = try graphics.Shader.setupShader("vertex.glsl", "fragment.glsl");
        var drawing = graphics.Drawing(.spatial).init(shader);

        drawing.bindVertex(&vertices, &indices);

        try drawing.textureFromPath("/home/saturnian/code/experiments/zig/ui-toolkit/comofas.png");
        try drawing.uniform4fv_array.append(.{ .name = "transform", .value = &cam.transform_mat.rows[0][0] });

        return Cube{ .drawing = drawing };
    }
};

pub fn makeAxis() !void {
    var line = try Line.init(.{ 0, 0.01, 0 }, .{ 2, 0, 0 }, .{ 1, 0, 0 });
    try scene.line_arr.append(line.drawing);

    line = try Line.init(.{ 0, 0.01, 0 }, .{ 0, 2, 0 }, .{ 0, 1, 0 });
    try scene.line_arr.append(line.drawing);

    line = try Line.init(.{ 0, 0.01, 0 }, .{ 0, 0, 2 }, .{ 0, 0, 1 });
    try scene.line_arr.append(line.drawing);
}

pub fn makeGrid() !void {
    const size = 100;
    for (0..size) |i| {
        var x: f32 = @floatFromInt(i);
        x -= size / 2;

        var line = try Line.init(.{ x, 0, -size / 2 }, .{ x, 0, size / 2 }, .{ 0.5, 0.5, 0.5 });
        try scene.line_arr.append(line.drawing);
        line = try Line.init(.{ -size / 2, 0, x }, .{ size / 2, 0, x }, .{ 0.5, 0.5, 0.5 });
        try scene.line_arr.append(line.drawing);
    }
}

pub fn main() !void {
    try graphics.initGraphics();
    var win = try graphics.Window.init(100, 100);
    defer win.deinit();

    gl.enable(gl.DEPTH_TEST);
    gl.enable(gl.CULL_FACE);
    gl.cullFace(gl.FRONT);

    win.setKeyCallback(keyFunc);

    cam = try Camera.init(0.6, 1, 0.1, 2048);

    //var comofas_png = graphics.Texture.init("../comofas.png");

    scene = try graphics.Scene.init();

    var cube = try Cube.init();
    try scene.spatial_arr.append(cube.drawing);

    try makeAxis();
    try makeGrid();

    var last_time: f32 = 0;

    while (win.alive) {
        graphics.waitGraphicsEvent();

        gl.clearColor(0.2, 0.2, 0.2, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const time = @as(f32, @floatCast(glfw.glfwGetTime()));

        if (down_num > 0) {
            try key_down(&current_keys, last_mods, time - last_time);
        }

        try scene.draw(win.*);

        graphics.glfw.glfwSwapBuffers(win.glfw_win);
    }
}
