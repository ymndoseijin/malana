const std = @import("std");

const ui = @import("ui");
const graphics = ui.graphics;
const Vec3 = ui.Vec3;
const Vertex = ui.Vertex;
const common = ui.common;

const State = ui.State;

const math = ui.math;

var state: *State = undefined;

var num_clicked: u32 = 0;

const b2 = @cImport({
    @cInclude("box2d/box2d.h");
});

fn keyDown(_: State.Context, key_state: ui.KeyState, mods: i32, dt: f32) !void {
    _ = mods;
    _ = dt;
    if (key_state.pressed_table[graphics.glfw.GLFW_KEY_Q]) {
        state.main_win.alive = false;
    }
}
fn nice(_: *anyopaque, _: *ui.Callback, _: i32, action: graphics.Action, _: i32) !void {
    if (action == .press) {
        std.debug.print("Hey!", .{});
        //state.scene.delete(state.scene.window.ally, color.drawing);
        num_clicked += 1;
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const ally = gpa.allocator();

    state = try State.init(ally, .{
        .window = .{
            .name = "image test",
            .width = 1920,
            .height = 1080,
            .resizable = true,
        },
        .scene = .{ .flip_z = true },
    });
    defer state.deinit(ally);

    state.main_win.setSize(1920, 1080);

    const gpu = &state.main_win.gpu;

    // get image file
    var arg_it = std.process.args();
    _ = arg_it.next();

    const image_path = arg_it.next() orelse return error.NotEnoughArguments;

    var tex = try graphics.Texture.initFromPath(ally, state.main_win, image_path, .{
        .mag_filter = .linear,
        .min_filter = .linear,
        .texture_type = .flat,
        .flip = true,
    });
    defer tex.deinit();

    var batch = try graphics.SpriteBatch.init(&state.scene, .{ .target = state.color_depth_target });
    defer batch.deinit(ally, gpu.*);

    // in meters
    const box_size = math.Vec2.init(.{ 1.0, 1.0 });
    const scale = 50.0;

    const transform: graphics.Transform2D = .{
        //.translation = math.Vec2.init(.{ 10, 10 }),
        .scale = box_size.scale(scale),
        .rotation = .{ .center = box_size.scale(0.5).scale(scale) },
    };

    var sprite = try batch.newSprite(gpu, .{
        .tex = tex,
        .uniform = .{
            .transform = transform.getMat().cast(4, 4).columns,
            .opacity = 1.0,
        },
    });

    sprite.transform = transform;

    std.debug.print("{d}\n", .{transform.getMat().cast(4, 4).columns});

    //try state.callback.elements.append(.{ @ptrCast(&color), .{ .mouse_func = nice, .region = &color_region } });

    var char_test = try graphics.TextFt.init(ally, .{
        .path = "resources/cmunrm.ttf",
        .size = 50,
        .line_spacing = 1,
        .bounding_width = 250,
        .scene = &state.scene,
        .target = state.color_depth_target,
    });
    char_test.transform.translation = math.Vec2.init(.{ 0, 200 });
    try char_test.print(ally, gpu, .{ .text = "hello world! " });
    try char_test.clear();
    try char_test.print(ally, gpu, .{ .text = "I'm here!" });
    defer char_test.deinit(ally, gpu.*);

    _ = try state.key_down_manager.subscribe(ally, .{ .func = keyDown });

    // TODO: properly check for errors
    var world_def = b2.b2DefaultWorldDef();
    world_def.gravity = .{ .x = 0.0, .y = -10.0 };

    const world_id = b2.b2CreateWorld(&world_def);

    var ground_body_def = b2.b2DefaultBodyDef();
    ground_body_def.position = .{ .x = 0.0, .y = -10.0 };

    const ground_id = b2.b2CreateBody(world_id, &ground_body_def);

    const ground_box = b2.b2MakeBox(50.0, 10.0);

    var ground_shape_def = b2.b2DefaultShapeDef();
    ground_shape_def.friction = 300;
    _ = b2.b2CreatePolygonShape(ground_id, &ground_shape_def, &ground_box);

    var body_def = b2.b2DefaultBodyDef();
    body_def.type = b2.b2_dynamicBody;
    body_def.position = .{ .x = 0.0, .y = 4.0 };

    const body_id = b2.b2CreateBody(world_id, &body_def);
    //const dynamic_box = b2.b2MakeBox(1.0, 1.0);
    var shape_def = b2.b2DefaultShapeDef();

    shape_def.density = 100.0;
    shape_def.friction = 300.0;

    //_ = b2.b2CreatePolygonShape(body_id, &shape_def, &dynamic_box);
    _ = b2.b2CreateCircleShape(body_id, &shape_def, &.{ .center = .{ .x = 0, .y = 0 }, .radius = 1 });

    const substep_count = 4;

    var pressed = false;

    const win = state.main_win;

    var last_pos = math.Vec2.init(.{ 0, 0 });
    var load_pos = math.Vec2.init(.{ 0, 0 });

    while (state.main_win.alive) {
        try state.updateEvents();

        // TODO: remove dt dependency
        b2.b2World_Step(world_id, state.dt, substep_count);

        const position_b2 = b2.b2Body_GetPosition(body_id);
        const rotation = b2.b2Body_GetRotation(body_id);

        const position = math.Vec2.init(.{ position_b2.x, position_b2.y });

        //std.debug.print("stuff: {any} {any}\n", .{ position, rotation });

        sprite.transform.rotation.angle = b2.b2Rot_GetAngle(rotation);
        sprite.transform.translation = position.scale(scale);
        sprite.updateTransform();

        var cursor_uv = win.getCursorPos();
        cursor_uv.val[1] = -cursor_uv.val[1];
        cursor_uv.val[1] += win.getSize().val[1];

        if (win.getMouseButton(0) == .press) {
            if (!pressed) {
                load_pos = cursor_uv.scale(1.0 / scale).sub(position);
                last_pos = cursor_uv.scale(1.0 / scale);
            }
            pressed = true;

            const force_pos = load_pos.add(position);
            const motion = cursor_uv.scale(1.0 / scale).sub(force_pos).scale(100);

            _ = b2.b2Body_ApplyForce(body_id, .{ .x = motion.val[0], .y = motion.val[1] }, .{
                .x = force_pos.val[0],
                .y = force_pos.val[1],
            }, true);
        }
        if (win.getMouseButton(0) == .release) pressed = false;

        const builder = &state.command_builder;
        const frame_id = builder.frame_id;
        const swapchain = &state.main_win.swapchain;

        // render graphics

        try swapchain.wait(gpu, frame_id);

        try state.scene.begin();

        state.image_index = try swapchain.acquireImage(gpu, frame_id);
        try builder.beginCommand(gpu);

        try state.scene.draw(builder, batch.drawing, state.image_index);
        try state.scene.draw(builder, char_test.batch.drawing, state.image_index);
        try state.scene.draw(builder, state.post_drawing, state.image_index);

        state.scene.end(builder);

        builder.transitionSwapimage(gpu, swapchain.getImage(state.image_index));

        try builder.endCommand(gpu);

        try swapchain.submit(gpu, state.command_builder, .{ .wait = &.{
            .{ .semaphore = swapchain.image_acquired[frame_id], .flag = .{ .color_attachment_output_bit = true } },
        } });
        try swapchain.present(gpu, .{ .wait = &.{swapchain.render_finished[frame_id]}, .image_index = state.image_index });
    }

    try state.main_win.gpu.vkd.deviceWaitIdle(state.main_win.gpu.dev);
}
