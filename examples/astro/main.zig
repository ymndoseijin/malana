const std = @import("std");

const ui = @import("ui");
const shaders = @import("shaders");

const astro_util = @import("astro_util.zig");

const State = ui.State;
const graphics = ui.graphics;
const Vec3 = ui.Vec3;
const Vertex = ui.Vertex;
const common = ui.common;

const math = ui.math;
const gl = ui.gl;

var astro_global: *Astro = undefined;

fn keyDown(_: State.Context, keys: ui.KeyState, mods: i32, dt: f32) !void {
    if (keys.pressed_table[graphics.glfw.GLFW_KEY_Q]) {
        astro_global.state.main_win.alive = false;
    }

    try astro_global.state.cam.spatialMove(keys.pressed_table, mods, dt, &astro_global.state.cam.move, graphics.Camera.DefaultSpatial);
}

pub fn makeSphere(ally: std.mem.Allocator) !ui.geometry.Mesh {
    var mesh = ui.geometry.Mesh.init(ally);

    var obj_parser = try ui.graphics.ObjParse.init(ally);
    var obj_builder = try obj_parser.parse("resources/cube.obj");
    defer obj_builder.deinit();

    var vertices = std.ArrayList(ui.geometry.Vertex).init(ally);
    defer vertices.deinit();

    for (obj_builder.vertices.items) |v| {
        try vertices.append(.{ .pos = Vec3.init(v[0]), .norm = Vec3.init(v[2]), .uv = math.Vec2.init(v[1]) });
    }

    try mesh.makeFrom(vertices.items, obj_builder.indices.items, 3);

    try mesh.subdivideMesh(5);

    var set = std.AutoHashMap(*ui.geometry.HalfEdge, void).init(ally);
    var stack = std.ArrayList(?*ui.geometry.HalfEdge).init(ally);

    defer set.deinit();
    defer stack.deinit();

    try stack.append(mesh.first_half);

    while (stack.items.len > 0) {
        const edge_or = stack.pop();
        if (edge_or) |edge| {
            if (set.get(edge)) |_| continue;
            try set.put(edge, void{});

            const position = &edge.vertex.pos;

            position.* = position.scale(1.0 / position.length());

            if (edge.next) |_| {
                if (edge.twin) |twin| {
                    try stack.append(twin);
                }
            }
            try stack.append(edge.next);
        }
    }

    try mesh.fixNormals();

    return mesh;
}

pub fn toMesh(half: *ui.geometry.HalfEdge, ally: std.mem.Allocator) !graphics.MeshBuilder {
    var builder = try graphics.MeshBuilder.init(ally);

    var set = std.AutoHashMap(*ui.geometry.HalfEdge, void).init(ally);
    var stack = std.ArrayList(?*ui.geometry.HalfEdge).init(ally);

    defer set.deinit();
    defer stack.deinit();

    try stack.append(half);

    while (stack.items.len > 0) {
        const edge_or = stack.pop();
        if (edge_or) |edge| {
            if (set.get(edge)) |_| continue;
            try set.put(edge, void{});

            const v = edge.face.vertices;

            const a = v[0].*;
            const b = v[1].*;
            const c = v[2].*;

            try builder.addTri(.{ a, b, c });

            if (edge.next) |_| {
                if (edge.twin) |twin| {
                    try stack.append(twin);
                }
            }
            try stack.append(edge.next);
        }
    }

    return builder;
}

pub const Material = struct {
    vert: graphics.Shader,
    frag: graphics.Shader,
    render_pipeline: graphics.RenderPipeline,

    pub fn init(state: *State, ally: std.mem.Allocator, options: struct {
        vert: []align(@alignOf(u32)) const u8,
        frag: []align(@alignOf(u32)) const u8,
        pipeline: graphics.PipelineDescription,
    }) !Material {
        const triangle_vert = try graphics.Shader.init(state.main_win.gpu, options.vert, .vertex);
        const triangle_frag = try graphics.Shader.init(state.main_win.gpu, options.frag, .fragment);

        const pipeline = try graphics.RenderPipeline.init(ally, .{
            .description = options.pipeline,
            .shaders = &.{ triangle_vert, triangle_frag },
            .rendering = state.main_win.rendering_options,
            .gpu = &state.main_win.gpu,
            .flipped_z = true,
        });

        return .{
            .vert = triangle_vert,
            .frag = triangle_frag,
            .render_pipeline = pipeline,
        };
    }

    pub fn deinit(material: *Material, gpu: graphics.Gpu) void {
        material.vert.deinit(gpu);
        material.frag.deinit(gpu);
        material.render_pipeline.deinit(&gpu);
    }
};

pub const Astro = struct {
    const PlanetUniform: graphics.DataDescription = .{ .T = extern struct { pos: [4]f32 } };

    const triangle_pipeline: graphics.PipelineDescription = .{
        .vertex_description = .{
            .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 }, .{ .size = 3 } },
        },
        .render_type = .triangle,
        .depth_test = true,
        .cull_type = .back,
        .sets = &.{
            .{
                .bindings = &.{
                    .{ .uniform = .{ .size = graphics.GlobalUniform.getSize() } },
                    .{ .uniform = .{
                        .size = PlanetUniform.getSize(),
                        .boundless = true,
                    } },
                },
            },
        },
        .constants_size = PushConstants.getSize(),
        .global_ubo = true,
        .bindless = true,
    };
    const PushConstants: graphics.DataDescription = .{ .T = extern struct {
        cam_pos: [3]f32 align(4 * 4),
        cam_transform: math.Mat4 align(4 * 4),
    } };

    state: *State,
    material: Material,
    object: graphics.SpatialMesh,
    fps: graphics.TextFt,
    planet_array: [8]astro_util.VsopPlanet,
    sphere: graphics.MeshBuilder,
    line: graphics.Line,

    pub fn init(ally: std.mem.Allocator) !Astro {
        const state = try State.init(ally, .{
            .window = .{ .name = "Astro", .width = 500, .height = 500, .resizable = true, .preferred_format = .srgb },
            .scene = .{ .flip_z = true },
        });

        // get obj file
        var arg_it = std.process.args();
        _ = arg_it.next();

        var sphere = try makeSphere(ally);
        defer sphere.deinit();
        const builder = try toMesh(sphere.first_half.?, ally);

        const material = try Material.init(state, ally, .{ .pipeline = triangle_pipeline, .vert = &shaders.vert, .frag = &shaders.frag });

        _ = try state.key_down_manager.subscribe(ally, .{ .func = keyDown });

        const color_target: graphics.RenderTarget = .{
            .texture = .{
                // kind of an issue, also kind of not really, just throw an arena
                .color_textures = try ally.dupe(*graphics.Texture, &.{&state.post_color_tex}),
                .depth_texture = &state.post_depth_tex,
                .region = .{},
            },
        };

        var fps = try graphics.TextFt.init(ally, .{
            .path = "resources/cmunrm.ttf",
            .size = 50,
            .line_spacing = 1,
            .bounding_width = 250,
            .scene = &state.scene,
            .target = color_target,
        });
        fps.transform.translation = math.Vec2.init(.{ 10, 10 });

        return .{
            .state = state,
            .material = material,
            .object = try builder.toSpatial(state.scene, try state.scene.new(), .{ .pipeline = material.render_pipeline, .target = color_target }),
            .fps = fps,
            .sphere = builder,
            .planet_array = .{
                try astro_util.VsopPlanet.init("mer", ally),
                try astro_util.VsopPlanet.init("ven", ally),
                try astro_util.VsopPlanet.init("ear", ally),
                try astro_util.VsopPlanet.init("mar", ally),
                try astro_util.VsopPlanet.init("jup", ally),
                try astro_util.VsopPlanet.init("sat", ally),
                try astro_util.VsopPlanet.init("ura", ally),
                try astro_util.VsopPlanet.init("nep", ally),
            },
            .line = try graphics.Line.init(&state.scene, .{ .pipeline = state.scene.default_pipelines.line, .target = color_target }),
        };
    }

    pub fn deinit(astro: *Astro, ally: std.mem.Allocator) void {
        const gpu = &astro.state.main_win.gpu;

        astro.object.drawing.deinitAllBuffers(ally, gpu.*);
        ally.destroy(astro.object.drawing);

        astro.fps.deinit(ally, gpu.*);
        astro.material.deinit(gpu.*);

        for (&astro.planet_array) |*planet| {
            planet.deinit(ally);
        }

        astro.sphere.deinit();

        astro.line.drawing.deinitAllBuffers(ally, gpu.*);
        ally.destroy(astro.line.drawing);

        //astro.sphere.deinit();
        //astro.builder.deinit();

        astro.state.deinit(ally);
        ally.destroy(astro.state);
    }

    pub fn render(astro: *Astro) !void {
        const state = astro.state;
        const gpu = &astro.state.main_win.gpu;

        const builder = &state.command_builder;
        const frame_id = builder.frame_id;
        const swapchain = &state.main_win.swapchain;

        const ally = state.ally;

        // render graphics

        for (&astro.planet_array, 0..) |*planet, i| {
            planet.update(state.time * 100);
            const pos = planet.pos.val;
            const pos_low: [4]f32 = .{ @floatCast(pos[0]), @floatCast(pos[1]), @floatCast(pos[2]), 0 };

            const planet_uniform = try astro.object.drawing.descriptor.getUniformOrCreate(gpu, 0, 1, @intCast(i));
            planet_uniform.setAsUniformField(PlanetUniform, .pos, pos_low);
        }

        astro.object.drawing.instances = astro.planet_array.len;

        const move = state.cam.move.val;
        //const pos = astro.planet.pos.val;

        //try astro.line.drawing.destroyVertex(gpu);

        const circle_count = 360;
        const circle = try ally.alloc(math.Vec3, circle_count + 1);
        defer ally.free(circle);

        for (circle, 0..) |*point, i| {
            const i_f: f32 = @floatFromInt(i);
            const count_float: f32 = @floatFromInt(circle_count);
            const ang = math.tau / count_float * i_f;

            const t_f: f32 = @floatCast(state.time);
            const r = (@cos(t_f * 0.7) + 1.0) / 2.0;

            point.* = .init(.{ r * @cos(ang * 3.0 + t_f * 1.6) + 1, r * @sin(ang * 2.0 + t_f * 1.6) + 1, 1.0 });
        }

        try state.scene.begin();

        state.image_index = try swapchain.acquireImage(gpu, frame_id);

        try builder.beginCommand(gpu);

        try astro.line.setVertex(state.main_win.ally, gpu, .{
            .thickness = 0.005,
            .vertices = circle,
        });

        builder.push(Astro.PushConstants, gpu, astro.material.render_pipeline.pipeline, &.{
            .cam_pos = move,
            .cam_transform = state.cam.transform_mat,
        });

        try state.scene.draw(builder, astro.object.drawing, state.image_index);
        try state.scene.draw(builder, astro.fps.batch.drawing, state.image_index);
        try state.scene.draw(builder, astro.line.drawing, state.image_index);
        try state.scene.draw(builder, state.post_drawing, state.image_index);

        state.scene.end(builder);

        builder.transitionSwapimage(gpu, swapchain.getImage(state.image_index));

        try builder.endCommand(gpu);

        try swapchain.submit(gpu, state.command_builder, .{ .wait = &.{
            .{ .semaphore = swapchain.image_acquired[frame_id], .flag = .{ .color_attachment_output_bit = true } },
        } });
        try swapchain.present(gpu, .{ .wait = &.{swapchain.render_finished[frame_id]}, .image_index = state.image_index });
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 32 }){};
    defer _ = gpa.deinit();

    const ally = gpa.allocator();

    var astro = try Astro.init(ally);
    defer astro.deinit(ally);
    astro_global = &astro;

    const state = astro.state;

    const gpu = &state.main_win.gpu;

    const swapchain = &state.main_win.swapchain;
    const builder = &state.command_builder;
    const frame_id = builder.frame_id;

    while (state.main_win.alive) {
        const frame = graphics.tracy.namedFrame("Frame");
        defer frame.end();

        try state.updateEvents();

        try swapchain.wait(gpu, frame_id);

        try astro.object.drawing.descriptor.setUniformOrCreate(graphics.SpatialMesh.Uniform, gpu, 0, 1, 0, .{
            .spatial_pos = .{ 0, 0, 0, 0 },
        });

        try astro.fps.clear();
        try astro.fps.printFmt(ally, gpu, "FPS: {}", .{@as(u32, @intFromFloat(1 / state.dt))});

        try astro.render();
    }

    try state.main_win.gpu.vkd.deviceWaitIdle(state.main_win.gpu.dev);
}
