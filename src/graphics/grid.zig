const std = @import("std");
const math = @import("math");
const gl = @import("gl");
const img = @import("img");
const geometry = @import("geometry");
const graphics = @import("graphics.zig");
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
const Line = @import("line.zig").Line;

pub fn makeGrid(scene: anytype, cam: anytype) !void {
    const size = 100;
    for (0..size) |i| {
        var x: f32 = @floatFromInt(i);
        x -= size / 2;

        var line = try Line.init(
            try scene.new(.line),
            &[_]Vec3{ .{ x, 0, -size / 2 }, .{ x, 0, size / 2 } },
            &[_]Vec3{ .{ 0.5, 0.5, 0.5 }, .{ 0.5, 0.5, 0.5 } },
            try graphics.Shader.setupShader(@embedFile("shaders/foggy_line/vertex.glsl"), @embedFile("shaders/foggy_line/fragment.glsl")),
        );

        try cam.linkDrawing(line.drawing);
        try line.drawing.addUniformVec3("cam_pos", &cam.move);

        line = try Line.init(
            try scene.new(.line),
            &[_]Vec3{ .{ -size / 2, 0, x }, .{ size / 2, 0, x } },
            &[_]Vec3{ .{ 0.5, 0.5, 0.5 }, .{ 0.5, 0.5, 0.5 } },
            try graphics.Shader.setupShader(@embedFile("shaders/foggy_line/vertex.glsl"), @embedFile("shaders/foggy_line/fragment.glsl")),
        );

        try cam.linkDrawing(line.drawing);
        try line.drawing.addUniformVec3("cam_pos", &cam.move);
    }
}
