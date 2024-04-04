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
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec3Utils = math.Vec3Utils;

const elem_shaders = @import("elem_shaders");

const DefaultSpriteUniform: graphics.DataDescription = .{ .T = extern struct { transform: math.Mat4, opacity: f32 } };

const SpriteInfo = struct {
    tex: graphics.Texture,
    pipeline: ?graphics.RenderPipeline = null,
};

pub const Sprite = CustomSprite(DefaultSpriteUniform);

pub fn CustomSprite(comptime SpriteUniform: graphics.DataDescription) type {
    return struct {
        pub const description: graphics.PipelineDescription = .{
            .vertex_description = .{
                .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 } },
            },
            .render_type = .triangle,
            .depth_test = false,
            .uniform_sizes = &.{ graphics.GlobalUniform.getSize(), SpriteUniform.getSize() },
            .global_ubo = true,
            .sampler_descriptions = &.{.{}},
        };

        pub const Self = @This();
        pub fn init(scene: *graphics.Scene, info: SpriteInfo) !Self {
            const w: f32 = @floatFromInt(info.tex.width);
            const h: f32 = @floatFromInt(info.tex.height);

            const default_transform: graphics.Transform2D = .{
                .scale = math.Vec2.init(.{ 1, 1 }),
                .rotation = .{ .angle = 0, .center = math.Vec2.init(.{ 0.5, 0.5 }) },
                .translation = math.Vec2.init(.{ 0, 0 }),
            };

            var drawing = try scene.new();

            try drawing.init(scene.window.ally, .{
                .win = scene.window,
                .pipeline = if (info.pipeline) |p| p else scene.default_pipelines.sprite,
                .samplers = &.{.{ .textures = &.{info.tex} }},
            });

            try description.vertex_description.bindVertex(drawing, &.{
                .{ .{ 0, 0, 1 }, .{ 0, 0 } },
                .{ .{ 1, 0, 1 }, .{ 1, 0 } },
                .{ .{ 1, 1, 1 }, .{ 1, 1 } },
                .{ .{ 0, 1, 1 }, .{ 0, 1 } },
            }, &.{ 0, 1, 2, 2, 3, 0 });

            SpriteUniform.setAsUniformField(drawing, 1, .transform, default_transform.getMat().cast(4, 4));
            SpriteUniform.setAsUniformField(drawing, 1, .opacity, 1);

            graphics.GlobalUniform.setAsUniform(drawing, 0, .{ .time = 0, .in_resolution = .{ 1, 1 } });

            return Self{
                .drawing = drawing,
                .width = w,
                .height = h,
                .opacity = 1.0,
                .transform = default_transform,
            };
        }

        pub fn updateTexture(self: *Sprite, ally: std.mem.Allocator, info: SpriteInfo) !void {
            try self.drawing.updateDescriptorSets(ally, &.{&.{info.tex}});

            const w: f32 = @floatFromInt(info.tex.width);
            const h: f32 = @floatFromInt(info.tex.height);

            self.width = w;
            self.height = h;
        }

        pub fn textureFromPath(self: *Self, path: []const u8) !Self {
            const wi, const hi = try self.drawing.textureFromPath(path);

            const w: f32 = @floatFromInt(wi);
            const h: f32 = @floatFromInt(hi);

            self.drawing.bindVertex(&.{
                0, 0, 1, 0, 0,
                1, 0, 1, 1, 0,
                1, 1, 1, 1, 1,
                0, 1, 1, 0, 1,
            }, &.{ 0, 1, 2, 2, 3, 0 });

            self.width = w;
            self.height = h;
        }

        pub fn updateTransform(self: Self) void {
            SpriteUniform.setAsUniformField(self.drawing, 1, .transform, self.transform.getMat().cast(4, 4));
        }

        pub fn setOpacity(self: *Self, opacity: f32) void {
            self.opacity = opacity;
            SpriteUniform.setAsUniformField(self.drawing, 1, .opacity, opacity);
        }

        width: f32,
        height: f32,
        opacity: f32,
        transform: graphics.Transform2D,

        drawing: *Drawing,
    };
}
