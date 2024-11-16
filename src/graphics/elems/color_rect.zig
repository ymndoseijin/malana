const std = @import("std");
const math = @import("math");
const geometry = @import("geometry");
const graphics = @import("../graphics.zig");
const trace = @import("../tracy.zig").trace;

const Drawing = graphics.Drawing;

const elem_shaders = @import("elem_shaders");

pub const ColorRect = struct {
    pub const Info = struct {
        pipeline: ?graphics.RenderPipeline = null,
        target: graphics.RenderTarget,
    };

    pub const Uniform: graphics.DataDescription = .{ .T = extern struct {
        size: [2]f32,
        position: [2]f32,
        color: [4]f32,
        roundness: f32,
    } };

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
                        .size = Uniform.getSize(),
                    } },
                },
            },
        },
        .global_ubo = true,
    };

    pub fn init(scene: *graphics.Scene, info: Info) !ColorRect {
        var drawing = try scene.new();

        const gpu = &scene.window.gpu;

        try drawing.init(scene.window.ally, gpu, .{
            .pipeline = scene.default_pipelines.color,
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
        };
    }

    pub fn deinit(rect: *ColorRect, ally: std.mem.Allocator, gpu: graphics.Gpu) void {
        rect.drawing.vertex_buffer.?.deinit(gpu);
        rect.drawing.index_buffer.?.deinit(gpu);

        rect.drawing.descriptor.deinitAllUniforms(gpu);
        rect.drawing.deinit(ally, gpu);
        ally.destroy(rect.drawing);
    }

    drawing: *Drawing,
};
