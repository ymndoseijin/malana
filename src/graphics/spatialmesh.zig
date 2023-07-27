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
const SpatialPipeline = graphics.SpatialPipeline;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec3Utils = math.Vec3Utils;

pub const SpatialMesh = struct {
    drawing: *Drawing(SpatialPipeline),
    pos: Vec3,

    pub fn initUniform(self: *SpatialMesh) !void {
        try self.drawing.addUniformVec3("spatial_pos", &self.pos);
    }

    pub fn init(drawing: *Drawing(SpatialPipeline), pos: Vec3, shader: u32) !SpatialMesh {
        drawing.* = graphics.Drawing(SpatialPipeline).init(shader);

        return SpatialMesh{
            .drawing = drawing,
            .pos = pos,
        };
    }
};
