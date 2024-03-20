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

const ColoredRectUniform: graphics.UniformDescription = .{ .type = extern struct { transform: math.Mat4, color: math.Vec4 } };

pub const ColoredRect = struct {
    pub const description: graphics.PipelineDescription = .{
        .vertex_description = .{
            .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 } },
        },
        .render_type = .triangle,
        .depth_test = false,
        .cull_type = .none,
        .uniform_sizes = &.{ graphics.GlobalUniform.getSize(), ColoredRectUniform.getSize() },
        .global_ubo = true,
    };

    pub fn init(scene: *graphics.Scene, color: math.Vec4) !ColoredRect {
        var drawing = try scene.new();

        try drawing.init(scene.window.ally, .{
            .win = scene.window,
            .pipeline = scene.default_pipelines.color,
        });

        const default_transform: graphics.Transform2D = .{
            .scale = .{ 1, 1 },
            .rotation = .{ .angle = 0, .center = .{ 0.5, 0.5 } },
            .translation = .{ 0, 0 },
        };

        try description.vertex_description.bindVertex(drawing, &.{
            .{ .{ 0, 0, 1 }, .{ 0, 0 } },
            .{ .{ 1, 0, 1 }, .{ 1, 0 } },
            .{ .{ 1, 1, 1 }, .{ 1, 1 } },
            .{ .{ 0, 1, 1 }, .{ 0, 1 } },
        }, &.{ 0, 1, 2, 2, 3, 0 });

        ColoredRectUniform.setUniform(drawing, 1, .{ .transform = default_transform.getMat().cast(4, 4), .color = color });
        graphics.GlobalUniform.setUniform(drawing, 0, .{ .time = 0, .in_resolution = .{ 1, 1 } });

        return ColoredRect{
            .drawing = drawing,
            .transform = default_transform,
        };
    }

    pub fn updateTransform(self: ColoredRect) void {
        ColoredRectUniform.setUniformField(self.drawing, 1, .transform, self.transform.getMat().cast(4, 4));
    }

    transform: graphics.Transform2D,
    drawing: *Drawing,
};
