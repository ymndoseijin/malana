const std = @import("std");
const math = @import("math");
const gl = @import("gl");
const img = @import("img");
const geometry = @import("geometry");
const graphics = @import("../graphics.zig");
const common = @import("common");

pub const Line = struct {
    pub const description: graphics.PipelineDescription = .{
        .vertex_description = .{
            .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 4 } },
        },
        .render_type = .triangle,
        .depth_test = false,
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
        target: graphics.RenderTarget,
    };

    pub fn set2D(line: *Line, ally: std.mem.Allocator, scene: *graphics.Scene, builder: graphics.CommandBuilder, info: struct {
        vertices: []const [2]f32,
        thickness: f32 = 0.1,
    }) !void {
        var vertices = std.ArrayList(description.vertex_description.getAttributeType()).init(ally);
        //defer vertices.deinit();

        var indices = std.ArrayList(u32).init(ally);
        //defer indices.deinit();

        for (0..info.vertices.len) |i_in| {
            const i: u32 = @intCast(i_in);
            if (i == 0) continue;

            const next = math.Vec2.init(info.vertices[i]);
            const vert = math.Vec2.init(info.vertices[i - 1]);

            const vec = next.sub(vert).norm();
            const parallel = math.Vec2.init(.{ -vec.val[1], vec.val[0] });

            const p1 = vert.add(parallel.scale(-1).scale(info.thickness)).val;
            const p0 = vert.add(parallel.scale(info.thickness)).val;

            const p2 = next.add(parallel.scale(info.thickness)).val;
            const p3 = next.add(parallel.scale(-1).scale(info.thickness)).val;

            try vertices.append(.{ .{ p0[0], p0[1], 1.0 }, .{ 1.0, 1.0, 1.0, 1.0 } });
            try vertices.append(.{ .{ p1[0], p1[1], 1.0 }, .{ 1.0, 1.0, 1.0, 1.0 } });
            try vertices.append(.{ .{ p2[0], p2[1], 1.0 }, .{ 1.0, 1.0, 1.0, 1.0 } });
            try vertices.append(.{ .{ p3[0], p3[1], 1.0 }, .{ 1.0, 1.0, 1.0, 1.0 } });

            try indices.append(4 * (i - 1));
            try indices.append(4 * (i - 1) + 1);
            try indices.append(4 * (i - 1) + 2);
            try indices.append(4 * (i - 1) + 1);
            try indices.append(4 * (i - 1) + 3);
            try indices.append(4 * (i - 1) + 2);
        }

        //std.debug.print("{any} {any}\n", .{ vertices.items, indices.items });

        //try description.vertex_description.bindVertex(line.drawing, vertices.items, indices.items, info.mode);
        try scene.bindVertex(builder, description.vertex_description, line.drawing, vertices.items, indices.items);
    }

    pub fn set(line: *Line, ally: std.mem.Allocator, info: struct {
        vertices: []const [3]f32,
        thickness: f32 = 0.1,
    }) !void {
        var vertices = std.ArrayList(description.vertex_description.getAttributeType()).init(ally);
        defer vertices.deinit();

        var indices = std.ArrayList(u32).init(ally);
        defer indices.deinit();

        for (0..info.vertices.len) |i_in| {
            const i: u32 = if (i_in == info.vertices.len - 1) @intCast(i_in - 1) else @intCast(i_in);
            const n_i: u32 = if (i_in == info.vertices.len - 1) @intCast(i_in) else @intCast(i_in + 1);

            if (i == 0) continue;

            const vert = math.Vec3.init(info.vertices[i]);
            const next = math.Vec3.init(info.vertices[n_i]);

            const vec = next.sub(vert).norm();
            const parallel = vec.cross(math.Vec3.init(.{ 0, 1, 0 })).norm().scale(info.thickness);

            try vertices.append(.{ vert.add(parallel.scale(-1)).val, .{ 1.0, 1.0, 1.0, 1.0 } });
            try vertices.append(.{ vert.add(parallel).val, .{ 1.0, 1.0, 1.0, 1.0 } });

            try indices.append(2 * (i - 1));
            try indices.append(2 * (i - 1) + 1);
            try indices.append(2 * (i - 1) + 2);
            try indices.append(2 * (i - 1) + 1);
            try indices.append(2 * (i - 1) + 3);
            try indices.append(2 * (i - 1) + 2);
        }

        try description.vertex_description.bindVertex(line.drawing, vertices.items, indices.items);
    }

    pub fn init(drawing: *graphics.Drawing, window: *graphics.Window, info: LineInfo) !Line {
        try drawing.init(window.ally, .{
            .win = window,
            .pipeline = info.pipeline,
            .target = info.target,
        });

        (try drawing.getUniformOrCreate(0, 0, 0)).setAsUniform(graphics.GlobalUniform, .{ .time = 0, .in_resolution = .{ 1, 1 } });

        return .{
            .drawing = drawing,
        };
    }
};
