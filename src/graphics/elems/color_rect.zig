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

pub const ColoredRect = struct {
    pub fn init(drawing: *Drawing(graphics.FlatPipeline), color: math.Vec4) !ColoredRect {
        var shader = try graphics.Shader.setupShader(@embedFile("shaders/color_rect/vertex.glsl"), @embedFile("shaders/color_rect/fragment.glsl"));

        drawing.* = graphics.Drawing(graphics.FlatPipeline).init(shader);

        drawing.bindVertex(&.{
            0, 0, 1, 0, 0,
            1, 0, 1, 1, 0,
            1, 1, 1, 1, 1,
            0, 1, 1, 0, 1,
        }, &.{ 0, 1, 2, 2, 3, 0 });

        drawing.shader.setUniformVec4("color", color);
        drawing.shader.setUniformMat3("transform", Mat3.identity());

        return ColoredRect{
            .drawing = drawing,
            .transform = .{
                .scale = .{ 1, 1 },
                .rotation = .{ .angle = 0, .center = .{ 0.5, 0.5 } },
                .translation = .{ 0, 0 },
            },
        };
    }

    pub fn updateTransform(self: ColoredRect) void {
        self.drawing.shader.setUniformMat3("transform", self.transform.getMat());
    }

    transform: graphics.Transform2D,
    drawing: *Drawing(graphics.FlatPipeline),
};
