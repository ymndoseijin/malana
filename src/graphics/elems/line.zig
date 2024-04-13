const std = @import("std");
const math = @import("math");
const gl = @import("gl");
const img = @import("img");
const geometry = @import("geometry");
const graphics = @import("../graphics.zig");
const common = @import("common");

pub const Line = struct {
    pub const Pipeline: graphics.PipelineDescription = .{
        .vertex_description = .{
            .vertex_attribs = &.{.{ .size = 3 }},
        },
        .render_type = .triangle,
        .depth_test = true,
        .cull_type = .none,
        .sets = &.{.{ .bindings = &.{
            .{ .uniform = .{ .size = graphics.GlobalUniform.getSize() } },
        } }},
        .global_ubo = true,
    };

    //pub const Uniform = InUniform;

    drawing: *graphics.Drawing,
    //vertices: []math.Vec3,

    const LineInfo = struct {
        pipeline: graphics.RenderPipeline,
    };

    const Self = @This();

    pub fn set(line: *Line, ally: std.mem.Allocator, info: struct {
        vertices: []const math.Vec3,
        thickness: f32 = 0.1,
    }) !void {
        var vertices = std.ArrayList(Pipeline.vertex_description.getAttributeType()).init(ally);
        defer vertices.deinit();

        var indices = std.ArrayList(u32).init(ally);
        defer indices.deinit();

        for (0..info.vertices.len) |i_in| {
            const i: u32 = if (i_in == info.vertices.len - 1) @intCast(i_in - 1) else @intCast(i_in);
            const n_i: u32 = if (i_in == info.vertices.len - 1) @intCast(i_in) else @intCast(i_in + 1);

            if (i == 0) continue;

            const vert = info.vertices[i];
            const next = info.vertices[n_i];

            const vec = next.sub(vert).norm();
            const parallel = vec.cross(math.Vec3.init(.{ 0, 1, 0 })).norm().scale(info.thickness);

            try vertices.append(.{vert.add(parallel.scale(-1)).val});
            try vertices.append(.{vert.add(parallel).val});

            try indices.append(2 * (i - 1));
            try indices.append(2 * (i - 1) + 1);
            try indices.append(2 * (i - 1) + 2);
            try indices.append(2 * (i - 1) + 1);
            try indices.append(2 * (i - 1) + 3);
            try indices.append(2 * (i - 1) + 2);
        }

        try Pipeline.vertex_description.bindVertex(line.drawing, vertices.items, indices.items);
    }

    pub fn init(drawing: *graphics.Drawing, window: *graphics.Window, info: LineInfo) !Self {
        try drawing.init(window.ally, .{
            .win = window,
            .pipeline = info.pipeline,
        });

        return .{
            .drawing = drawing,
        };
    }
};
