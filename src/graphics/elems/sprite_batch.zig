const std = @import("std");
const math = @import("math");
const geometry = @import("geometry");
const graphics = @import("../graphics.zig");
const trace = @import("../tracy.zig").trace;

const Drawing = graphics.Drawing;

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
            .depth_write = false,
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

            const gpu = &scene.window.gpu;

            try drawing.init(scene.window.ally, gpu, .{
                .pipeline = if (info.pipeline) |p| p else scene.default_pipelines.sprite_batch,
                .queue = &scene.queue,
                .target = info.target,
            });

            try description.vertex_description.bindVertex(drawing, gpu, &.{
                .{ .{ 0, 0, 1 }, .{ 0, 0 } },
                .{ .{ 1, 0, 1 }, .{ 1, 0 } },
                .{ .{ 1, 1, 1 }, .{ 1, 1 } },
                .{ .{ 0, 1, 1 }, .{ 0, 1 } },
            }, &.{ 0, 1, 2, 2, 3, 0 }, .immediate);

            return .{
                .drawing = drawing,
                .ally = scene.window.ally,
                .sprite_indices = .empty,
                .textures = .empty,
            };
        }

        pub fn deinit(batch: *ThisBatch, ally: std.mem.Allocator, gpu: graphics.Gpu) void {
            batch.drawing.vertex_buffer.?.deinit(gpu);
            batch.drawing.index_buffer.?.deinit(gpu);

            batch.drawing.descriptor.deinitAllUniforms(gpu);
            batch.drawing.deinit(ally, gpu);
            ally.destroy(batch.drawing);

            batch.sprite_indices.deinit(ally);
            batch.textures.deinit(ally);
        }

        //const current_idx: u32 = @intCast(batch.sprite_indices.items.len);
        pub fn clear(batch: *ThisBatch) void {
            batch.sprite_indices.clearRetainingCapacity();
            batch.textures.clearRetainingCapacity();
            batch.drawing.instances = 0;
        }

        pub const Sprite = struct {
            idx: u32,
            width: f32,
            height: f32,
            opacity: f32,
            transform: graphics.Transform2D,

            // TODO: not currently working
            pub fn delete(sprite: Sprite, batch: *ThisBatch) !void {
                const tracy = trace(@src());
                defer tracy.end();

                const current = batch.sprite_indices.items[sprite.idx];
                const last = batch.sprite_indices.items[batch.sprite_indices.items.len - 1];
                batch.sprite_indices.shrinkRetainingCapacity(batch.sprite_indices.items.len - 1);

                batch.drawing.getUniformOr(0, 1, current).getData().* = batch.drawing.getUniform(0, 1, last).getData().*;
                const ally = batch.drawing.window.ally;
                std.debug.print("current dst: {}\n", .{current});
                try batch.drawing.updateDescriptorSets(ally, .{ .samplers = &.{.{
                    .set = 1,
                    .idx = 0,
                    .dst = current,
                    .textures = &.{batch.textures[last]},
                }} });

                batch.textures[sprite.idx] = batch.textures.items[batch.textures.items.len - 1];
                batch.textures.shrinkRetainingCapacity(batch.textures.items.len - 1);
            }

            pub fn getUniformOr(sprite: Sprite, batch: ThisBatch, binding: u32) ?graphics.BufferHandle {
                return batch.drawing.descriptor.getUniformOr(0, binding, batch.sprite_indices.items[sprite.idx]);
            }

            pub fn updateTransform(sprite: Sprite, batch: ThisBatch) void {
                sprite.getUniformOr(batch, 1).?.setAsUniformField(SpriteUniform, .transform, sprite.transform.getMat().cast(4, 4).columns);
            }
            pub fn setOpacity(sprite: *Sprite, opacity: f32) void {
                sprite.opacity = opacity;
                sprite.getUniformOr(1).?.setAsUniformField(SpriteUniform, .opacity, opacity);
            }
            pub fn setTexture(sprite: *Sprite, batch: ThisBatch, tex: graphics.Texture) !void {
                const ally = batch.drawing.window.ally;
                batch.textures[sprite.idx] = tex;
                try batch.drawing.updateDescriptorSets(ally, .{ .samplers = &.{.{
                    .set = 1,
                    .idx = 0,
                    .dst = batch.sprite_indices[sprite.idx],
                    .textures = &.{tex},
                }} });
            }
        };

        pub fn newSprite(batch: *ThisBatch, gpu: *graphics.Gpu, options: struct {
            transform: graphics.Transform2D = .{
                .scale = math.Vec2.init(.{ 1, 1 }),
                .rotation = .{ .angle = 0, .center = math.Vec2.init(.{ 0.5, 0.5 }) },
                .translation = math.Vec2.init(.{ 0, 0 }),
            },
            tex: graphics.Texture,
            uniform: SpriteUniform.T,
        }) !Sprite {
            const ally = batch.ally;

            const tracy = trace(@src());
            defer tracy.end();

            const w: f32 = @floatFromInt(options.tex.width);
            const h: f32 = @floatFromInt(options.tex.height);

            const current_idx: u32 = @intCast(batch.sprite_indices.items.len);
            try batch.sprite_indices.append(ally, current_idx);
            batch.drawing.instances = @intCast(batch.sprite_indices.items.len);

            const uniform = try batch.drawing.descriptor.getUniformOrCreate(gpu, 0, 1, current_idx);

            //uniform.setAsUniformField(SpriteUniform, .transform, default_transform.getMat().cast(4, 4).columns);
            //uniform.setAsUniformField(SpriteUniform, .opacity, 1.0);

            uniform.setAsUniform(SpriteUniform, options.uniform);

            try batch.drawing.descriptor.updateDescriptorSets(gpu, .{ .samplers = &.{.{
                .set = 1,
                .idx = 0,
                .dst = current_idx,
                .textures = &.{options.tex},
            }} });

            return .{
                .idx = current_idx,
                .width = w,
                .height = h,
                .opacity = 1.0,
                .transform = options.transform,
            };
        }

        drawing: *Drawing,
        // TODO: remove
        ally: std.mem.Allocator,

        sprite_indices: std.ArrayList(u32),
        textures: std.ArrayList(graphics.Texture),
    };
}
