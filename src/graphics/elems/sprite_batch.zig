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

pub const SpriteBatch = CustomSpriteBatch(DefaultSpriteUniform);

pub fn CustomSpriteBatch(comptime SpriteUniform: graphics.DataDescription) type {
    return struct {
        pub const Info = struct {
            pipeline: ?graphics.RenderPipeline = null,
        };

        pub const description: graphics.PipelineDescription = .{
            .vertex_description = .{
                .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 }, .{ .size = 1, .attribute = .uint } },
            },
            .render_type = .triangle,
            .depth_test = false,
            .uniform_descriptions = &.{ .{
                .size = graphics.GlobalUniform.getSize(),
                .idx = 0,
            }, .{
                .size = SpriteUniform.getSize(),
                .idx = 1,
                .boundless = true,
            } },
            .global_ubo = true,
            .sampler_descriptions = &.{.{
                .idx = 2,
                .boundless = true,
            }},
        };

        pub const ThisBatch = @This();
        pub fn init(scene: *graphics.Scene, info: Info) !ThisBatch {
            var drawing = try scene.new();

            try drawing.init(scene.window.ally, .{
                .win = scene.window,
                .pipeline = if (info.pipeline) |p| p else scene.default_pipelines.spritebatch,
            });

            return .{
                .drawing = drawing,
                .vertices = std.ArrayList(description.vertex_description.getAttributeType()).init(scene.window.ally),
                .indices = std.ArrayList(u32).init(scene.window.ally),
                .count = 0,
            };
        }

        const ThisSprite = struct {
            batch: *ThisBatch,
            idx: u32,
            width: f32,
            height: f32,
            opacity: f32,
            transform: graphics.Transform2D,

            pub fn getUniformOr(sprite: ThisSprite, binding: u32) ?graphics.BufferHandle {
                return sprite.batch.drawing.getUniformOr(binding, sprite.idx);
            }

            pub fn updateTransform(sprite: ThisSprite) void {
                sprite.getUniformOr(1).?.setAsUniformField(SpriteUniform, .transform, sprite.transform.getMat().cast(4, 4));
            }
            pub fn setOpacity(sprite: *ThisSprite, opacity: f32) void {
                sprite.opacity = opacity;
                sprite.getUniformOr(1).?.setAsUniformField(SpriteUniform, .opacity, opacity);
            }
            pub fn setTexture(sprite: *ThisSprite, tex: graphics.Texture) !void {
                const ally = sprite.batch.drawing.window.ally;
                try sprite.batch.drawing.updateDescriptorSets(ally, .{ .samplers = &.{.{ .dst = sprite.idx, .idx = 2, .textures = &.{tex} }} });
            }
        };

        pub fn newSprite(batch: *ThisBatch, tex: graphics.Texture) !ThisSprite {
            const ally = batch.drawing.window.ally;
            const w: f32 = @floatFromInt(tex.width);
            const h: f32 = @floatFromInt(tex.height);

            const default_transform: graphics.Transform2D = .{
                .scale = math.Vec2.init(.{ 1, 1 }),
                .rotation = .{ .angle = 0, .center = math.Vec2.init(.{ 0.5, 0.5 }) },
                .translation = math.Vec2.init(.{ 0, 0 }),
            };

            const current_idx = batch.count;
            for (0..2) |i| _ = try batch.drawing.getUniformOrCreate(@intCast(i), current_idx);
            batch.count += 1;

            try batch.indices.appendSlice(&.{
                current_idx + 0,
                current_idx + 1,
                current_idx + 2,
                current_idx + 2,
                current_idx + 3,
                current_idx + 0,
            });

            const idx2: i32 = @intCast(current_idx);
            try batch.vertices.appendSlice(&.{
                .{ .{ 0, 0, 1 }, .{ 0, 0 }, .{idx2} },
                .{ .{ 1, 0, 1 }, .{ 1, 0 }, .{idx2} },
                .{ .{ 1, 1, 1 }, .{ 1, 1 }, .{idx2} },
                .{ .{ 0, 1, 1 }, .{ 0, 1 }, .{idx2} },
            });

            try description.vertex_description.bindVertex(batch.drawing, batch.vertices.items, batch.indices.items);

            batch.drawing.getUniformOr(1, current_idx).?.setAsUniformField(SpriteUniform, .transform, default_transform.getMat().cast(4, 4));
            batch.drawing.getUniformOr(1, current_idx).?.setAsUniformField(SpriteUniform, .opacity, 1.0);
            batch.drawing.getUniformOr(1, current_idx).?.setAsUniform(graphics.GlobalUniform, .{ .time = 0, .in_resolution = .{ 1, 1 } });

            try batch.drawing.updateDescriptorSets(ally, .{ .samplers = &.{.{ .dst = current_idx, .idx = 2, .textures = &.{tex} }} });

            //.vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 }, .{ .size = 1, .attribute = .uint } },
            //const tipo = description.vertex_description.getAttributeType();
            //@compileLog(@offsetOf(tipo, "2"));

            return .{
                .batch = batch,
                .idx = current_idx,
                .width = w,
                .height = h,
                .opacity = 1.0,
                .transform = default_transform,
            };
        }

        drawing: *Drawing,
        vertices: std.ArrayList(description.vertex_description.getAttributeType()),
        indices: std.ArrayList(u32),
        count: u32,
    };
}
