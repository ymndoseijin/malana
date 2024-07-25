const std = @import("std");
const math = @import("math");
const gl = @import("gl");
const img = @import("img");
const geometry = @import("geometry");
const graphics = @import("../graphics.zig");
const common = @import("common");
const trace = @import("../tracy.zig").trace;

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

const DefaultSpriteUniform: graphics.DataDescription = .{ .T = extern struct { transform: [4][4]f32, opacity: f32 } };

pub const SpriteBatch = CustomSpriteBatch(DefaultSpriteUniform);

pub fn CustomSpriteBatch(comptime SpriteUniform: graphics.DataDescription) type {
    return struct {
        pub const Info = struct {
            pipeline: ?graphics.RenderPipeline = null,
            target: graphics.RenderTarget,
        };

        pub const description: graphics.PipelineDescription = .{
            .vertex_description = .{
                .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 } },
            },
            .render_type = .triangle,
            .depth_test = false,
            .sets = &.{
                .{
                    .bindings = &.{
                        .{ .uniform = .{
                            .size = graphics.GlobalUniform.getSize(),
                        } },
                        .{ .uniform = .{
                            .size = SpriteUniform.getSize(),
                            .boundless = true,
                        } },
                    },
                },
                .{
                    .bindings = &.{
                        .{ .sampler = .{ .boundless = true } },
                    },
                },
            },
            .global_ubo = true,
            .bindless = true,
        };

        pub const ThisBatch = @This();
        pub fn init(scene: *graphics.Scene, info: Info) !ThisBatch {
            var drawing = try scene.new();

            try drawing.init(scene.window.ally, .{
                .win = scene.window,
                .pipeline = if (info.pipeline) |p| p else scene.default_pipelines.sprite_batch,
                .queue = &scene.queue,
                .target = info.target,
            });

            try description.vertex_description.bindVertex(drawing, &.{
                .{ .{ 0, 0, 1 }, .{ 0, 0 } },
                .{ .{ 1, 0, 1 }, .{ 1, 0 } },
                .{ .{ 1, 1, 1 }, .{ 1, 1 } },
                .{ .{ 0, 1, 1 }, .{ 0, 1 } },
            }, &.{ 0, 1, 2, 2, 3, 0 }, .immediate);

            return .{
                .drawing = drawing,
                .sprite_indices = std.ArrayList(u32).init(scene.window.ally),
                .textures = std.ArrayList(graphics.Texture).init(scene.window.ally),
            };
        }

        pub fn deinit(batch: *ThisBatch, ally: std.mem.Allocator, gpu: graphics.Gpu) void {
            batch.drawing.vertex_buffer.?.deinit(gpu);
            batch.drawing.index_buffer.?.deinit(gpu);

            batch.drawing.descriptor.deinitAllUniforms();
            batch.drawing.deinit(ally);
            ally.destroy(batch.drawing);

            batch.sprite_indices.deinit();
            batch.textures.deinit();
        }

        pub fn clear(batch: *ThisBatch) void {
            batch.sprite_indices.clearRetainingCapacity();
            batch.textures.clearRetainingCapacity();
            batch.drawing.instances = 0;
        }

        pub const Sprite = struct {
            batch: *ThisBatch,
            idx: u32,
            width: f32,
            height: f32,
            opacity: f32,
            transform: graphics.Transform2D,

            pub fn delete(sprite: Sprite) !void {
                std.debug.print("wa\n", .{});
                const tracy = trace(@src());
                defer tracy.end();

                const batch = sprite.batch;

                const current = batch.sprite_indices[sprite.idx];
                const last = batch.sprite_indices.items[batch.sprite_indices.items.len - 1];
                batch.sprite_indices.shrinkRetainingCapacity(batch.sprite_indices.items.len - 1);

                batch.drawing.getUniform(0, 1, current).getData().* = batch.drawing.getUniform(0, 1, last).getData().*;
                const ally = batch.drawing.window.ally;
                try batch.drawing.updateDescriptorSets(ally, .{ .samplers = &.{.{
                    .set = 1,
                    .idx = 0,
                    .dst = current,
                    .textures = &.{batch.textures[last]},
                }} });

                batch.textures[sprite.idx] = batch.textures.items[batch.textures.items.len - 1];
                batch.textures.shrinkRetainingCapacity(batch.textures.items.len - 1);
            }

            pub fn getUniformOr(sprite: Sprite, binding: u32) ?graphics.BufferHandle {
                return sprite.batch.drawing.getUniformOr(0, binding, sprite.batch.sprite_indices.items[sprite.idx]);
            }

            pub fn updateTransform(sprite: Sprite) void {
                sprite.getUniformOr(1).?.setAsUniformField(SpriteUniform, .transform, sprite.transform.getMat().cast(4, 4).columns);
            }
            pub fn setOpacity(sprite: *Sprite, opacity: f32) void {
                sprite.opacity = opacity;
                sprite.getUniformOr(1).?.setAsUniformField(SpriteUniform, .opacity, opacity);
            }
            pub fn setTexture(sprite: *Sprite, tex: graphics.Texture) !void {
                const ally = sprite.batch.drawing.window.ally;
                sprite.batch.textures[sprite.idx] = tex;
                try sprite.batch.drawing.updateDescriptorSets(ally, .{ .samplers = &.{.{
                    .set = 1,
                    .idx = 0,
                    .dst = sprite.batch.sprite_indices[sprite.idx],
                    .textures = &.{tex},
                }} });
            }
        };

        pub fn newSprite(batch: *ThisBatch, options: struct { tex: graphics.Texture, uniform: SpriteUniform.T }) !Sprite {
            const tracy = trace(@src());
            defer tracy.end();

            const ally = batch.drawing.window.ally;
            const w: f32 = @floatFromInt(options.tex.width);
            const h: f32 = @floatFromInt(options.tex.height);

            const default_transform: graphics.Transform2D = .{
                .scale = math.Vec2.init(.{ 1, 1 }),
                .rotation = .{ .angle = 0, .center = math.Vec2.init(.{ 0.5, 0.5 }) },
                .translation = math.Vec2.init(.{ 0, 0 }),
            };

            const current_idx: u32 = @intCast(batch.sprite_indices.items.len);
            try batch.sprite_indices.append(current_idx);
            batch.drawing.instances = @intCast(batch.sprite_indices.items.len);

            const uniform = try batch.drawing.getUniformOrCreate(0, 1, current_idx);

            //uniform.setAsUniformField(SpriteUniform, .transform, default_transform.getMat().cast(4, 4).columns);
            //uniform.setAsUniformField(SpriteUniform, .opacity, 1.0);

            uniform.setAsUniform(SpriteUniform, options.uniform);

            try batch.drawing.updateDescriptorSets(ally, .{ .samplers = &.{.{
                .set = 1,
                .idx = 0,
                .dst = current_idx,
                .textures = &.{options.tex},
            }} });

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

        sprite_indices: std.ArrayList(u32),
        textures: std.ArrayList(graphics.Texture),
    };
}
