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
const SpatialPipeline = graphics.SpatialPipeline;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec3Utils = math.Vec3Utils;

pub const SpatialMesh = struct {
    drawing: *Drawing,
    pos: Vec3,

    const SpatialInfo = struct {
        pos: Vec3 = .{ 0, 0, 0 },
        shaders: []graphics.Shader,
        pipeline: graphics.RenderPipeline = graphics.SpatialPipeline,
    };

    pub fn init(scene: *graphics.Scene, info: SpatialInfo) !SpatialMesh {
        var drawing = try scene.new();
        try drawing.init(scene.window.ally, .{ .win = scene.window, .shaders = info.shaders, .pipeline = info.pipeline, .flipped_z = true });

        graphics.SpatialUniform.setUniformField(drawing, 1, .spatial_pos, info.pos);
        graphics.GlobalUniform.setUniform(drawing, 0, .{ .time = 0, .in_resolution = .{ 1, 1 } });

        return SpatialMesh{
            .drawing = drawing,
            .pos = info.pos,
        };
    }
};
