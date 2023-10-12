const std = @import("std");
const math = @import("math");
const gl = @import("gl");
const img = @import("img");
const geometry = @import("geometry");
const graphics = @import("../graphics.zig");
const common = @import("common");

const BdfParse = @import("parsing").BdfParse;

const Mesh = geometry.Mesh;
const Vertex = geometry.Vertex;
const HalfEdge = geometry.HalfEdge;

const Drawing = graphics.Drawing;
const glfw = graphics.glfw;
const Mat3 = math.Mat3;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec3Utils = math.Vec3Utils;

pub const ColoredRectInfo = struct {
    color: Vec3,
    transform: Mat3,
};

pub const ColoredRect = struct {
    pub fn init(drawing: *Drawing(graphics.FlatPipeline), info: ColoredRectInfo) !ColoredRect {
        var shader = try graphics.Shader.setupShader(@embedFile("shaders/color_rect/vertex.glsl"), @embedFile("shaders/color_rect/fragment.glsl"));

        drawing.* = graphics.Drawing(graphics.FlatPipeline).init(shader);

        drawing.bindVertex(&.{
            0, 0, 0, 0, 0,
            1, 0, 0, 1, 0,
            1, 1, 0, 1, 1,
            0, 1, 0, 0, 1,
        }, &.{ 0, 1, 2, 2, 3, 0 });

        drawing.setUniformVec3("color", info.color);
        drawing.setUniformMat3("transform", info.transform);

        return ColoredRect{
            .drawing = drawing,
        };
    }

    drawing: *Drawing(graphics.FlatPipeline),
};
