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

const max_lights = 256;

const Light = extern struct {
    pos: [3]f32 align(4 * 4),
    intensity: [3]f32 align(4 * 4),
};

pub const DefaultUniform: graphics.DataDescription = .{
    .T = extern struct {
        spatial_pos: [3]f32 align(4 * 4),
        light_count: i32,
        lights: [max_lights]Light,
    },
};

pub const SpatialMesh = CustomSpatialMesh(DefaultUniform);

pub fn CustomSpatialMesh(comptime InUniform: graphics.DataDescription) type {
    return struct {
        pub const Pipeline: graphics.PipelineDescription = .{
            .vertex_description = .{
                .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 }, .{ .size = 3 } },
            },
            .render_type = .triangle,
            .depth_test = true,
            .cull_type = .back,
            .uniform_descriptions = &.{ .{
                .size = graphics.GlobalUniform.getSize(),
                .idx = 0,
            }, .{
                .size = Uniform.getSize(),
                .idx = 1,
            } },
            .global_ubo = true,
        };

        pub const Uniform = InUniform;

        drawing: *Drawing,
        pos: Vec3,

        const SpatialInfo = struct {
            pos: Vec3 = Vec3.init(.{ 0, 0, 0 }),
            pipeline: graphics.RenderPipeline,
        };

        const Self = @This();

        pub fn init(scene: *graphics.Scene, info: SpatialInfo) !Self {
            var drawing = try scene.new();
            try drawing.init(scene.window.ally, .{
                .win = scene.window,
                .pipeline = info.pipeline,
            });

            drawing.getUniformOr(1, 0).?.setAsUniformField(Uniform, .spatial_pos, info.pos.val);
            drawing.getUniformOr(0, 0).?.setAsUniform(graphics.GlobalUniform, .{ .time = 0, .in_resolution = .{ 1, 1 } });

            return .{
                .drawing = drawing,
                .pos = info.pos,
            };
        }
    };
}
