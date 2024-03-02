const std = @import("std");
const math = @import("math");
const gl = @import("gl");
const img = @import("img");
const geometry = @import("geometry");
const graphics = @import("../graphics.zig");
const common = @import("common");

const BdfParse = @import("parsing").BdfParse;

const Pga = geometry.Pga;
const Point = Pga.Point;

const Mesh = geometry.Mesh;
const Vertex = geometry.Vertex;
const HalfEdge = geometry.HalfEdge;

const Drawing = graphics.Drawing;
const glfw = graphics.glfw;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec3Utils = math.Vec3Utils;

const TAU = 6.28318530718;

pub const Camera = struct {
    perspective_mat: math.Mat4,

    transform_mat: math.Mat4,

    move: @Vector(3, f32) = .{ 0, 0, 0 },
    up: @Vector(3, f32) = .{ 0, 1, 0 },

    eye: [2]f32 = .{ 4.32, -0.23 },

    pub fn updateMat(self: *Camera) !void {
        const eye_x = self.eye[0];
        const eye_y = self.eye[1];

        const eye = Vec3{ std.math.cos(eye_x) * std.math.cos(eye_y), std.math.sin(eye_y), std.math.sin(eye_x) * std.math.cos(eye_y) };

        const view_mat = math.lookAtMatrix(.{ 0, 0, 0 }, eye, self.up);
        //const translation_mat = Mat4.translation(-self.move);

        self.transform_mat = self.perspective_mat.mul(view_mat);
    }

    pub fn getRay(self: Camera) Pga.Line.Type {
        const eye_x = self.eye[0];
        const eye_y = self.eye[1];

        const eye = Vec3{ std.math.cos(eye_x) * std.math.cos(eye_y), std.math.sin(eye_y), std.math.sin(eye_x) * std.math.cos(eye_y) };

        return Point.create(self.move).regressive(Point.create(self.move + eye));
    }

    pub fn linkDrawing(self: *Camera, drawing: *Drawing) !void {
        graphics.SpatialUniform.setUniformField(drawing, 1, .transform, self.transform_mat);
        graphics.SpatialUniform.setUniformField(drawing, 1, .cam_pos, self.move);
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

    const SpatialFormat = struct {
        look_speed: f32,
        move_speed: f32,

        look_multiplier: f32,
        speed_multiplier: f32,

        speed_boost_key: usize,
        look_boost_key: usize,

        forward_key: usize,
        backward_key: usize,
        leftward_key: usize,
        rightward_key: usize,
        upward_key: usize,
        downward_key: usize,

        right_look_key: usize,
        left_look_key: usize,
        up_look_key: usize,
        down_look_key: usize,
    };
    pub const DefaultSpatial = SpatialFormat{
        .look_speed = 1,
        .move_speed = 10,

        .speed_multiplier = 7,
        .look_multiplier = 2,

        .speed_boost_key = glfw.GLFW_KEY_LEFT_SHIFT,
        .look_boost_key = glfw.GLFW_KEY_LEFT_SHIFT,

        .forward_key = glfw.GLFW_KEY_W,
        .backward_key = glfw.GLFW_KEY_S,
        .leftward_key = glfw.GLFW_KEY_A,
        .rightward_key = glfw.GLFW_KEY_D,
        .upward_key = glfw.GLFW_KEY_R,
        .downward_key = glfw.GLFW_KEY_F,

        .right_look_key = glfw.GLFW_KEY_L,
        .left_look_key = glfw.GLFW_KEY_H,
        .up_look_key = glfw.GLFW_KEY_K,
        .down_look_key = glfw.GLFW_KEY_J,
    };

    pub fn spatialMove(cam: *Camera, keys: []const bool, mods: i32, dt: f32, cam_pos: anytype, format: SpatialFormat) !void {
        _ = mods;
        var look_speed: f32 = format.look_speed * dt;
        var speed: f32 = format.move_speed * dt;

        const eye_x = cam.eye[0];
        const eye_y = cam.eye[1];

        if (keys[format.speed_boost_key]) {
            speed *= format.speed_multiplier;
        }

        if (keys[format.look_boost_key]) {
            look_speed *= format.look_multiplier;
        }

        const speed_vec: Vec3 = @splat(speed);
        const eye = speed_vec * Vec3{ std.math.cos(eye_x) * std.math.cos(eye_y), std.math.sin(eye_y), std.math.sin(eye_x) * std.math.cos(eye_y) };

        const cross_eye = speed_vec * -Vec3Utils.crossn(eye, cam.up);

        const up_eye = speed_vec * Vec3Utils.crossn(eye, cross_eye);

        //if (keys[glfw.GLFW_KEY_Q]) {
        //    main_win.alive = false;
        //}

        if (keys[format.forward_key]) {
            cam_pos.* += eye;
        }

        if (keys[format.backward_key]) {
            cam_pos.* -= eye;
        }

        if (keys[format.leftward_key]) {
            cam_pos.* += cross_eye;
        }

        if (keys[format.rightward_key]) {
            cam_pos.* -= cross_eye;
        }

        if (keys[format.upward_key]) {
            cam_pos.* += up_eye;
        }

        if (keys[format.downward_key]) {
            cam_pos.* -= up_eye;
        }

        if (keys[format.right_look_key]) {
            cam.eye[0] += look_speed;
        }

        if (keys[format.left_look_key]) {
            cam.eye[0] -= look_speed;
        }

        if (keys[format.up_look_key]) {
            if (cam.eye[1] < TAU) cam.eye[1] += look_speed;
        }

        if (keys[format.down_look_key]) {
            if (cam.eye[1] > -TAU) cam.eye[1] -= look_speed;
        }

        try cam.updateMat();
    }
};
