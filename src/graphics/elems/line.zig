const std = @import("std");
const math = @import("math");
const geometry = @import("geometry");
const graphics = @import("../graphics.zig");
const trace = @import("../tracy.zig").trace;

const Drawing = graphics.Drawing;

pub const Line = struct {
    pub const Info = struct {
        pipeline: ?graphics.RenderPipeline = null,
        target: graphics.RenderTarget,
    };

    pub const Uniform: graphics.DataDescription = .{ .T = extern struct {
        color: [4]f32,
    } };

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
                        .size = Uniform.getSize(),
                    } },
                },
            },
        },
        .global_ubo = true,
    };

    pub fn init(scene: *graphics.Scene, info: Info) !Line {
        var drawing = try scene.new();

        const gpu = &scene.window.gpu;

        try drawing.init(scene.window.ally, gpu, .{
            .pipeline = scene.default_pipelines.line,
            .queue = &scene.queue,
            .target = info.target,
        });

        return .{
            .drawing = drawing,
        };
    }

    pub fn setVertex(line: *Line, ally: std.mem.Allocator, gpu: *graphics.Gpu, options: struct {
        thickness: f32,
        vertices: []const math.Vec3,
    }) !void {
        const Vertex = struct { [3]f32, [2]f32 };
        const vertices = try ally.alloc(Vertex, (options.vertices.len - 1) * 4);
        defer ally.free(vertices);

        const indices = try ally.alloc(u32, (options.vertices.len - 1) * 6);
        defer ally.free(indices);

        var i: usize = 0;
        var vertices_i: u32 = 0;
        var index_i: u32 = 0;

        while (i + 1 < options.vertices.len) : ({
            i += 1;
            vertices_i += 4;
            index_i += 6;
        }) {
            const will_merge = i + 2 < options.vertices.len;
            const start_pos: math.Vec3 = options.vertices[i];
            const end_pos: math.Vec3 = options.vertices[i + 1];

            const difference = end_pos.sub(start_pos).norm();

            const up: math.Vec3 = .init(.{ 0, 0, 1 });

            const parallel = difference.cross(up).scale(options.thickness);

            const end_parallel = blk: {
                if (will_merge) {
                    const after_pos: math.Vec3 = options.vertices[i + 2];
                    const end_difference = after_pos.sub(end_pos).norm();

                    break :blk end_difference.cross(up).scale(options.thickness);
                } else {
                    break :blk parallel;
                }
            };

            const vert_source: [4]Vertex = .{
                .{ start_pos.sub(parallel).val, .{ 0, 0 } },
                .{ end_pos.sub(end_parallel).val, .{ 1, 0 } },
                .{ end_pos.add(end_parallel).val, .{ 1, 1 } },
                .{ start_pos.add(parallel).val, .{ 0, 1 } },
            };

            @memcpy(vertices[vertices_i .. vertices_i + 4], &vert_source);

            const index_source: [6]u32 = .{
                vertices_i,
                vertices_i + 1,
                vertices_i + 2,
                vertices_i + 2,
                vertices_i + 3,
                vertices_i,
            };

            @memcpy(indices[index_i .. index_i + 6], &index_source);
        }

        try description.vertex_description.bindVertex(line.drawing, gpu, vertices, indices, .immediate);
    }

    pub fn deinit(rect: *Line, ally: std.mem.Allocator, gpu: graphics.Gpu) void {
        rect.drawing.vertex_buffer.?.deinit(gpu);
        rect.drawing.index_buffer.?.deinit(gpu);

        rect.drawing.descriptor.deinitAllUniforms(gpu);
        rect.drawing.deinit(ally, gpu);
        ally.destroy(rect.drawing);
    }

    drawing: *Drawing,
};
