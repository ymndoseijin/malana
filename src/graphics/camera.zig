const std = @import("std");
const math = @import("math");
const gl = @import("gl");
const img = @import("img");
const geometry = @import("geometry");
const graphics = @import("graphics");
const common = @import("common");

const BdfParse = @import("parsing").BdfParse;

const Mesh = geometry.Mesh;
const Vertex = geometry.Vertex;
const HalfEdge = geometry.HalfEdge;

const Drawing = graphics.Drawing;
const glfw = graphics.glfw;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec3Utils = math.Vec3Utils;

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
        const translation_mat = Mat4.translation(-self.move);

        self.transform_mat = self.perspective_mat.mul(view_mat.mul(translation_mat));
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
