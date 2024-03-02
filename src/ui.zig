pub const std = @import("std");
pub const math = @import("math");
pub const gl = @import("gl");
pub const numericals = @import("numericals");
pub const img = @import("img");
pub const geometry = @import("geometry");
pub const graphics = @import("graphics");
pub const common = @import("common");
pub const parsing = @import("parsing");
pub const Ui = @import("ui/ui.zig").Ui;
pub const Callback = @import("ui/ui.zig").Callback;
pub const Region = @import("ui/ui.zig").Region;
pub const KeyState = @import("ui/ui.zig").KeyState;

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
            b.fixed_size[1] = text_box.content.bounding_height;
            try b.resolveChildren(false);
        }
    }

    fn textBind(box: *Box, text_ptr: *anyopaque) !void {
        var text_box: *TextBox = @ptrCast(@alignCast(text_ptr));

        text_box.content.bounding_width = box.current_size[0];
        text_box.content.transform.translation = box.absolute_pos;

        try text_box.content.update();
        try text_box.update();
    }

    pub fn getTextCallback(text_box: *TextBox) BoxCallback {
        return .{ .box = &text_box.box, .fun = textBind, .data = text_box };
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
