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
const LinePipeline = graphics.LinePipeline;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec3Utils = math.Vec3Utils;

pub const Line = struct {
    pub fn init(drawing: *Drawing(LinePipeline), vert: []const Vec3, color: []const Vec3, shader: u32) !Line {
        //var shader = try graphics.Shader.setupShader(@embedFile("shaders/line/vertex.glsl"), @embedFile("shaders/line/fragment.glsl"));
        drawing.* = graphics.Drawing(LinePipeline).init(shader);

        var vertices = std.ArrayList(f32).init(common.allocator);
        var indices = std.ArrayList(u32).init(common.allocator);

        defer vertices.deinit();
        defer indices.deinit();

        for (vert, color, 0..) |v, c, i| {
            const arr = .{ v[0], v[1], v[2], c[0], c[1], c[2] };
            inline for (arr) |f| {
                try vertices.append(f);
            }
            try indices.append(@intCast(i));
        }

        drawing.bindVertex(vertices.items, indices.items);

        return Line{
            .vertices = vertices.items,
            .indices = indices.items,
            .drawing = drawing,
        };
    }
    vertices: []f32,
    indices: []u32,
    drawing: *Drawing(LinePipeline),
};
