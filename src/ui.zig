pub const std = @import("std");
pub const math = @import("math");
pub const gl = @import("gl");
pub const numericals = @import("numericals");
pub const img = @import("img");
pub const geometry = @import("geometry");
pub const graphics = @import("graphics");
pub const common = @import("common");
pub const parsing = @import("parsing");
pub const State = @import("State.zig");
pub const Callback = State.Callback;
pub const Region = State.Region;
pub const KeyState = State.KeyState;

pub const Box = @import("ui/box.zig").Box;
pub const MarginBox = @import("ui/box.zig").MarginBox;
pub const BoxCallback = @import("ui/box.zig").Callback;

fn colorBoxBind(box: *Box, color_ptr: *anyopaque) !void {
    var color: *graphics.ColoredRect = @ptrCast(@alignCast(color_ptr));

    color.transform.scale = box.current_size;
    color.transform.translation = box.absolute_pos;
    color.updateTransform();
}

pub fn getColorCallback(color: *graphics.ColoredRect) BoxCallback {
    return .{ .fun = colorBoxBind, .data = color };
}

fn spriteBoxBind(box: *Box, sprite_ptr: *anyopaque) !void {
    var sprite: *graphics.Sprite = @ptrCast(@alignCast(sprite_ptr));

    sprite.transform.scale = box.current_size;
    sprite.transform.translation = box.absolute_pos;
    sprite.updateTransform();
}

pub fn getSpriteCallback(sprite: *graphics.Sprite) BoxCallback {
    return .{ .fun = spriteBoxBind, .data = sprite };
}

fn regionBind(box: *Box, region_ptr: *anyopaque) !void {
    var region: *Region = @ptrCast(@alignCast(region_ptr));

    region.transform.scale = box.current_size;
    region.transform.translation = box.absolute_pos;
}

pub fn getRegionCallback(region: *Region) BoxCallback {
    return .{ .fun = regionBind, .data = region };
}

pub const TextBox = struct {
    content: graphics.TextFt,
    box: ?*Box = null,

    pub fn init(text: graphics.TextFt) TextBox {
        return .{
            .content = text,
        };
    }

    pub fn update(text_box: *TextBox) !void {
        if (text_box.box) |b| {
            b.fixed_size.val[0] = text_box.content.width;
            b.fixed_size.val[1] = text_box.content.bounding_height;
            try b.resolveChildren(false);
        }
    }

    fn textBind(box: *Box, text_ptr: *anyopaque) !void {
        var text_box: *TextBox = @ptrCast(@alignCast(text_ptr));

        text_box.content.bounding_width = box.current_size.val[0];
        text_box.content.transform.translation = box.absolute_pos;

        try text_box.content.update();
        try text_box.update();
    }

    pub fn getCallback(text_box: *TextBox) BoxCallback {
        return .{ .box = &text_box.box, .fun = textBind, .data = text_box };
    }
};

const NineInfo = struct {
    top_left: *Box,
    left: *Box,
    bottom_left: *Box,
    top: *Box,
    bottom: *Box,
    top_right: *Box,
    right: *Box,
    bottom_right: *Box,
};

pub const NineRectTexture = struct {
    top_left: graphics.Texture,
    left: graphics.Texture,
    bottom_left: graphics.Texture,
    top: graphics.Texture,
    bottom: graphics.Texture,
    top_right: graphics.Texture,
    right: graphics.Texture,
    bottom_right: graphics.Texture,

    pub fn deinit(textures: NineRectTexture) void {
        textures.top_left.deinit();
        textures.left.deinit();
        textures.bottom_left.deinit();
        textures.top.deinit();
        textures.bottom.deinit();
        textures.top_right.deinit();
        textures.right.deinit();
        textures.bottom_right.deinit();
    }
};

pub const NineRectSprite = struct {
    top_left_sprite: graphics.Sprite,
    left_sprite: graphics.Sprite,
    bottom_left_sprite: graphics.Sprite,
    top_sprite: graphics.Sprite,
    bottom_sprite: graphics.Sprite,
    top_right_sprite: graphics.Sprite,
    right_sprite: graphics.Sprite,
    bottom_right_sprite: graphics.Sprite,

    box: ?*Box,

    pub fn updateTexture(sprite: *NineRectSprite, ally: std.mem.Allocator, texture: NineRectTexture) !void {
        try sprite.top_left_sprite.updateTexture(ally, .{ .tex = texture.top_left });
        try sprite.left_sprite.updateTexture(ally, .{ .tex = texture.left });
        try sprite.bottom_left_sprite.updateTexture(ally, .{ .tex = texture.bottom_left });
        try sprite.top_sprite.updateTexture(ally, .{ .tex = texture.top });
        try sprite.bottom_sprite.updateTexture(ally, .{ .tex = texture.bottom });
        try sprite.top_right_sprite.updateTexture(ally, .{ .tex = texture.top_right });
        try sprite.right_sprite.updateTexture(ally, .{ .tex = texture.right });
        try sprite.bottom_right_sprite.updateTexture(ally, .{ .tex = texture.bottom_right });

        const box = sprite.box orelse return;

        box.leaves.items[0].leaves.items[0].fixed_size.val = .{ @floatFromInt(texture.top_left.width), @floatFromInt(texture.top_left.height) };
        box.leaves.items[0].leaves.items[1].fixed_size.val = .{ @floatFromInt(texture.left.width), @floatFromInt(texture.left.height) };
        box.leaves.items[0].leaves.items[2].fixed_size.val = .{ @floatFromInt(texture.bottom_left.width), @floatFromInt(texture.bottom_left.height) };

        box.leaves.items[1].leaves.items[0].fixed_size.val = .{ @floatFromInt(texture.top.width), @floatFromInt(texture.top.height) };
        box.leaves.items[1].leaves.items[2].fixed_size.val = .{ @floatFromInt(texture.bottom.width), @floatFromInt(texture.bottom.height) };

        box.leaves.items[2].leaves.items[0].fixed_size.val = .{ @floatFromInt(texture.top_right.width), @floatFromInt(texture.top_right.height) };
        box.leaves.items[2].leaves.items[1].fixed_size.val = .{ @floatFromInt(texture.right.width), @floatFromInt(texture.right.height) };
        box.leaves.items[2].leaves.items[2].fixed_size.val = .{ @floatFromInt(texture.bottom_right.width), @floatFromInt(texture.bottom_right.height) };

        try box.resolve();
    }

    pub fn init(scene: *graphics.Scene, texture: NineRectTexture) !NineRectSprite {
        return .{
            .top_left_sprite = try graphics.Sprite.init(scene, .{ .tex = texture.top_left }),
            .left_sprite = try graphics.Sprite.init(scene, .{ .tex = texture.left }),
            .bottom_left_sprite = try graphics.Sprite.init(scene, .{ .tex = texture.bottom_left }),
            .top_sprite = try graphics.Sprite.init(scene, .{ .tex = texture.top }),
            .bottom_sprite = try graphics.Sprite.init(scene, .{ .tex = texture.bottom }),
            .top_right_sprite = try graphics.Sprite.init(scene, .{ .tex = texture.top_right }),
            .right_sprite = try graphics.Sprite.init(scene, .{ .tex = texture.right }),
            .bottom_right_sprite = try graphics.Sprite.init(scene, .{ .tex = texture.bottom_right }),
            .box = null,
        };
    }

    pub fn makeBox(rect: *NineRectSprite, ally: std.mem.Allocator, in_box: *Box) !*Box {
        const box = try NineRectBox(ally, .{
            .top_left = try Box.create(ally, .{
                .label = "top left",
                .size = .{ rect.top_left_sprite.width, rect.top_left_sprite.height },
                .callbacks = &.{getSpriteCallback(&rect.top_left_sprite)},
            }),
            .bottom_left = try Box.create(ally, .{
                .label = "bottom left",
                .size = .{ rect.bottom_left_sprite.width, rect.bottom_left_sprite.height },
                .callbacks = &.{getSpriteCallback(&rect.bottom_left_sprite)},
            }),
            .top_right = try Box.create(ally, .{
                .label = "top right",
                .size = .{ rect.top_right_sprite.width, rect.top_right_sprite.height },
                .callbacks = &.{getSpriteCallback(&rect.top_right_sprite)},
            }),
            .bottom_right = try Box.create(ally, .{
                .label = "bottom right",
                .size = .{ rect.bottom_right_sprite.width, rect.bottom_right_sprite.height },
                .callbacks = &.{getSpriteCallback(&rect.bottom_right_sprite)},
            }),
            .top = try Box.create(ally, .{
                .label = "top",
                .expand = .{ .horizontal = true },
                .size = .{ rect.top_sprite.width, rect.top_sprite.height },
                .callbacks = &.{getSpriteCallback(&rect.top_sprite)},
            }),
            .bottom = try Box.create(ally, .{
                .label = "bottom",
                .expand = .{ .horizontal = true },
                .size = .{ rect.bottom_sprite.width, rect.bottom_sprite.height },
                .callbacks = &.{getSpriteCallback(&rect.bottom_sprite)},
            }),
            .left = try Box.create(ally, .{
                .label = "left",
                .expand = .{ .vertical = true },
                .size = .{ rect.left_sprite.width, rect.left_sprite.height },
                .callbacks = &.{getSpriteCallback(&rect.left_sprite)},
            }),
            .right = try Box.create(ally, .{
                .label = "right",
                .expand = .{ .vertical = true },
                .size = .{ rect.right_sprite.width, rect.right_sprite.height },
                .callbacks = &.{getSpriteCallback(&rect.right_sprite)},
            }),
        }, in_box);
        rect.box = box;
        return box;
    }

    pub fn deinit(rect: NineRectSprite, ally: std.mem.Allocator, scene: *graphics.Scene) void {
        scene.delete(ally, rect.top_left_sprite.drawing);
        scene.delete(ally, rect.left_sprite.drawing);
        scene.delete(ally, rect.bottom_left_sprite.drawing);
        scene.delete(ally, rect.top_sprite.drawing);
        scene.delete(ally, rect.bottom_sprite.drawing);
        scene.delete(ally, rect.top_right_sprite.drawing);
        scene.delete(ally, rect.right_sprite.drawing);
        scene.delete(ally, rect.bottom_right_sprite.drawing);
    }
};

pub fn NineRectBox(ally: std.mem.Allocator, info: NineInfo, box: *Box) !*Box {
    return try Box.create(ally, .{
        .label = "nine rect",
        .flow = .{ .horizontal = true },
        .expand = box.expand,
        .fit = .{ .vertical = true, .horizontal = true },
        .children = &.{
            try Box.create(ally, .{
                .label = "left nine",
                .flow = .{ .vertical = true },
                .expand = .{ .vertical = true },
                .fit = .{ .vertical = true, .horizontal = true },
                .size = .{ 0, 0 },
                .children = &.{
                    info.top_left,
                    info.left,
                    info.bottom_left,
                },
            }),
            try Box.create(ally, .{
                .label = "middle nine",
                .flow = .{ .vertical = true },
                .expand = .{ .vertical = true, .horizontal = true },
                .fit = .{ .vertical = true, .horizontal = true },
                .children = &.{
                    info.top,
                    box,
                    info.bottom,
                },
            }),
            try Box.create(ally, .{
                .label = "right nine",
                .flow = .{ .vertical = true },
                .expand = .{ .vertical = true },
                .fit = .{ .vertical = true, .horizontal = true },
                .size = .{ 0, 0 },
                .children = &.{
                    info.top_right,
                    info.right,
                    info.bottom_right,
                },
            }),
        },
    });
}

pub const ButtonTexture = struct {
    hover: NineRectTexture = undefined,
    idle: NineRectTexture,
    pressed: NineRectTexture,

    hover_inner: graphics.Texture = undefined,
    idle_inner: graphics.Texture,
    pressed_inner: graphics.Texture = undefined,

    pub fn deinit(textures: ButtonTexture) void {
        //textures.hover.deinit();
        textures.idle.deinit();
        textures.pressed.deinit();
        //textures.hover_inner.deinit();
        textures.idle_inner.deinit();
        //textures.pressed_inner.deinit();
    }
};

pub const Button = struct {
    border: NineRectSprite,
    inner: graphics.Sprite,
    text: TextBox,
    region: Region,
    texture: ButtonTexture,
    margins: f32,
    ally: std.mem.Allocator,
    box: ?*Box,

    const ButtonInfo = struct {
        label: []const u8,
        texture: ButtonTexture,
        margins: f32,
    };

    pub fn init(scene: *graphics.Scene, ally: std.mem.Allocator, info: ButtonInfo) !Button {
        const inner = try graphics.Sprite.init(scene, .{ .tex = info.texture.idle_inner });
        var text = TextBox.init(try graphics.TextFt.init(ally, .{
            .path = "resources/fonts/Fairfax.ttf",
            .size = 12,
            .line_spacing = 1,
            .wrap = false,
        }));

        try text.content.print(scene, ally, .{ .text = info.label, .color = .{ 0.0, 0.0, 0.0 } });

        return .{
            .border = try NineRectSprite.init(scene, info.texture.idle),
            .inner = inner,
            .text = text,
            .region = .{ .transform = .{} },
            .texture = info.texture,
            .margins = info.margins,
            .ally = ally,
            .box = null,
        };
    }

    pub fn deinit(button: *Button, scene: *graphics.Scene) void {
        button.border.deinit(button.ally, scene);
        button.text.content.deinit(button.ally, scene);
        scene.delete(button.ally, button.inner.drawing);
    }

    fn mouseButton(button_ptr: *anyopaque, callback: *Callback, button_clicked: i32, action: graphics.Action, _: i32) !void {
        const button: *Button = @alignCast(@ptrCast(button_ptr));

        if (button_clicked == 0) {
            if (action == .press) {
                try button.border.updateTexture(button.ally, button.texture.pressed);
            } else if (action == .release) {
                try button.border.updateTexture(button.ally, button.texture.idle);
                try callback.unfocus();
            }
        }
    }

    pub fn makeBox(button: *Button, current_ui: *State, ally: std.mem.Allocator) !*Box {
        try current_ui.callback.elements.append(.{
            @ptrCast(button), .{
                .mouse_func = Button.mouseButton,
                .region = &button.region,
            },
        });

        const m = button.margins;
        button.box = try button.border.makeBox(ally, try Box.create(ally, .{
            .size = .{ button.inner.width, button.inner.height },
            .fit = .{ .vertical = true, .horizontal = true },
            .callbacks = &.{
                getSpriteCallback(&button.inner),
                getRegionCallback(&button.region),
            },
            .children = &.{
                try MarginBox(ally, .{ .top = m, .bottom = m, .left = m, .right = m }, try Box.create(ally, .{
                    .callbacks = &.{
                        button.text.getCallback(),
                    },
                })),
            },
        }));

        return button.box.?;
    }
};

pub const InputBox = struct {
    region: Region,
    text_box: TextBox,
    background: graphics.ColoredRect,
    border: NineRectSprite,
    ally: std.mem.Allocator,
    scene: *graphics.Scene,
    text: std.ArrayList(u8),
    on_send: ?SendCallback,
    box: ?*Box,

    const SendCallback = struct { ptr: *anyopaque, func: *const fn (*anyopaque, *InputBox, []const u8) anyerror!void };
    pub const InputInfo = struct {
        border_texture: NineRectTexture,
        on_send: ?SendCallback = null,
    };

    pub fn init(scene: *graphics.Scene, ally: std.mem.Allocator, info: InputInfo) !InputBox {
        const input_box = try graphics.ColoredRect.init(scene, comptime try math.color.parseHexRGBA("8e8eb9"));
        const text_box = TextBox.init(try graphics.TextFt.init(ally, .{
            .path = "resources/fonts/Fairfax.ttf",
            .size = 12,
            .line_spacing = 1,
            .bounding_width = 250,
        }));

        const text_region: Region = .{ .transform = input_box.transform };

        return .{
            .region = text_region,
            .text_box = text_box,
            .background = input_box,
            .text = std.ArrayList(u8).init(ally),
            .ally = ally,
            .scene = scene,
            .border = try NineRectSprite.init(scene, info.border_texture),
            .on_send = info.on_send,
            .box = null,
        };
    }

    pub fn deinit(input: *InputBox) void {
        input.border.deinit(input.ally, input.scene);
        input.text_box.content.deinit(input.ally, input.scene);
        input.scene.delete(input.ally, input.background.drawing);
    }

    pub fn makeBox(input: *InputBox, current_ui: *State, ally: std.mem.Allocator) !*Box {
        try current_ui.callback.elements.append(.{ @ptrCast(input), .{
            .key_func = keyInput,
            .char_func = textInput,
            .region = &input.region,
        } });
        const box = try input.border.makeBox(ally, try Box.create(ally, .{
            .label = "Text",
            .expand = .{ .horizontal = true },
            .size = .{ 0, 30 },
            .callbacks = &.{
                getColorCallback(&input.background),
                getRegionCallback(&input.region),
                input.text_box.getCallback(),
            },
        }));
        input.box = box;
        return box;
    }

    fn keyInput(input_ptr: *anyopaque, _: *Callback, key: i32, scancode: i32, action: graphics.Action, mods: i32) !void {
        _ = scancode;
        _ = mods;
        const input: *InputBox = @alignCast(@ptrCast(input_ptr));

        if (key == graphics.glfw.GLFW_KEY_ENTER and action == .press) {
            if (input.on_send) |on_send| try on_send.func(on_send.ptr, input, input.text.items);
            input.text.clearRetainingCapacity();
            try input.text_box.content.clear(input.scene, input.ally);
            if (input.box) |b| try b.resolve();
        } else if (key == graphics.glfw.GLFW_KEY_BACKSPACE and action == .press) {
            if (input.text.items.len == 0) return;
            var text = &input.text_box.content;
            if (input.text.items[input.text.items.len - 1] != ' ') {
                const char = text.characters.pop();
                input.scene.delete(input.ally, char.sprite.drawing);
                char.deinit(input.ally);
            }

            var buf: [4]u8 = undefined;
            const codepoint = text.codepoints.pop();
            const string = buf[0..try std.unicode.utf8Encode(@intCast(codepoint), &buf)];
            input.text.shrinkRetainingCapacity(input.text.items.len - string.len);
        }
    }

    fn textInput(input_ptr: *anyopaque, _: *Callback, codepoint: u32) !void {
        const input: *InputBox = @alignCast(@ptrCast(input_ptr));

        var buf: [4]u8 = undefined;
        const string = buf[0..try std.unicode.utf8Encode(@intCast(codepoint), &buf)];
        for (string) |c| try input.text.append(c);
        try input.text_box.content.print(input.scene, input.ally, .{ .text = string, .color = .{ 0.0, 0.0, 0.0 } });
    }
};

pub const Mesh = geometry.Mesh;
pub const Vertex = geometry.Vertex;
pub const HalfEdge = geometry.HalfEdge;

pub const Drawing = graphics.Drawing;
pub const glfw = graphics.glfw;

pub const Camera = graphics.Camera;
pub const Cube = graphics.Cube;
pub const Line = graphics.Line;
pub const MeshBuilder = graphics.MeshBuilder;

pub const Mat4 = math.Mat4;
pub const Vec2 = math.Vec2;
pub const Vec3 = math.Vec3;
pub const Vec4 = math.Vec4;
pub const Vec3Utils = math.Vec3Utils;

pub const SpatialPipeline = graphics.SpatialPipeline;
