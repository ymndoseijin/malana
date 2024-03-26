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
const SpatialPipeline = graphics.SpatialPipeline;
const glfw = graphics.glfw;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec3Utils = math.Vec3Utils;

pub const MeshBuilder = struct {
    const VertTuple = struct { [3]f32, [2]f32, [3]f32 };
    vertices: std.ArrayList(VertTuple),
    indices: std.ArrayList(u32),
    count: u32,

    pub fn deinit(self: *MeshBuilder) void {
        self.vertices.deinit();
        self.indices.deinit();
    }

    pub fn addTri(self: *MeshBuilder, v: [3]Vertex) !void {
        const vertices = [_]VertTuple{
            .{ .{ v[0].pos.val[0], v[0].pos.val[1], v[0].pos.val[2] }, .{ v[0].uv.val[0], v[0].uv.val[1] }, .{ v[0].norm.val[0], v[0].norm.val[1], v[0].norm.val[2] } },
            .{ .{ v[1].pos.val[0], v[1].pos.val[1], v[1].pos.val[2] }, .{ v[1].uv.val[0], v[1].uv.val[1] }, .{ v[1].norm.val[0], v[1].norm.val[1], v[1].norm.val[2] } },
            .{ .{ v[2].pos.val[0], v[2].pos.val[1], v[2].pos.val[2] }, .{ v[2].uv.val[0], v[2].uv.val[1] }, .{ v[2].norm.val[0], v[2].norm.val[1], v[2].norm.val[2] } },
        };

        const indices = [_]u32{
            self.count, self.count + 1, self.count + 2,
        };

        inline for (vertices) |vert| {
            try self.vertices.append(vert);
        }

        inline for (indices) |i| {
            try self.indices.append(i);
        }

        self.count += 3;
    }

    const SpatialFormat = struct {
        vert: [:0]const u8,
        frag: [:0]const u8,
        pos: Vec3 = .{ 0, 0, 0 },
    };

    pub fn toSpatial(self: MeshBuilder, drawing: *Drawing(SpatialPipeline), comptime format: SpatialFormat) !graphics.SpatialMesh {
        _ = self;
        return try graphics.SpatialMesh.init(
            drawing,
            format.pos,
            try graphics.Shader.setupShader(format.vert, format.frag),
        );
    }

    pub fn init(ally: std.mem.Allocator) !MeshBuilder {
        return MeshBuilder{
            .count = 0,
            .vertices = std.ArrayList(VertTuple).init(ally),
            .indices = std.ArrayList(u32).init(ally),
        };
    }
};
