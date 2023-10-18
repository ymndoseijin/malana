const std = @import("std");
const math = @import("math");
const gl = @import("gl");
const img = @import("img");
const geometry = @import("geometry");
const graphics = @import("../graphics.zig");
const common = @import("common");
const freetype = @import("freetype");

const BdfParse = @import("parsing").BdfParse;

const Mesh = geometry.Mesh;
const Vertex = geometry.Vertex;
const HalfEdge = geometry.HalfEdge;

const Drawing = graphics.Drawing;
const glfw = graphics.glfw;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec3Utils = math.Vec3Utils;

const fs = 15;

pub fn bdfToRgba(res: []bool) ![fs * fs]img.color.Rgba32 {
    var buf: [fs * fs]img.color.Rgba32 = undefined;
    for (res, 0..) |val, i| {
        if (val) {
            buf[i] = .{ .r = 255, .g = 255, .b = 255, .a = 255 };
        } else {
            buf[i] = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
        }
    }
    return buf;
}

const Image = graphics.Image;

pub const Character = struct {
    image: Image,
    sprite: graphics.Sprite,
    offset: math.Vec2,
    advance: f32,

    pub fn init(face: freetype.Face, char: u32, scene: anytype) !Character {
        try face.loadChar(char, .{ .render = true });
        const glyph = face.glyph();
        const bitmap = glyph.bitmap();

        var image: Image = .{
            .data = try common.allocator.alloc(img.color.Rgba32, bitmap.rows() * bitmap.width()),
            .width = bitmap.width(),
            .height = bitmap.rows(),
        };

        const metrics = glyph.metrics();
        var offset: math.Vec2 = .{ @floatFromInt(metrics.horiBearingX), @floatFromInt(-metrics.height + metrics.horiBearingY) };

        const metrics_scale: math.Vec2 = @splat(1.0 / 64.0);
        offset *= metrics_scale;

        const advance: f32 = @floatFromInt(metrics.horiAdvance);

        for (0..bitmap.rows()) |i| {
            for (0..bitmap.width()) |j| {
                var s: u8 = bitmap.buffer().?[i * bitmap.width() + j];
                image.data[i * image.width + j] = .{ .r = 255, .g = 255, .b = 255, .a = s };
            }
        }

        return .{
            .image = image,
            .sprite = try graphics.Sprite.init(scene, .{ .rgba = image }),
            .offset = offset,
            .advance = advance / 64,
        };
    }

    pub fn deinit(self: Character) void {
        common.allocator.free(self.image.data);
    }
};

pub const Text = struct {
    characters: std.ArrayList(Character),
    face: freetype.Face,

    width: f32,
    height: f32,

    line_spacing: f32,
    bounding_width: f32,

    transform: graphics.Transform2D,

    pub fn printFmt(self: *Text, scene: anytype, comptime fmt: []const u8, fmt_args: anytype) !void {
        var buf: [4098]u8 = undefined;
        var str = try std.fmt.bufPrint(&buf, fmt, fmt_args);
        try self.print(scene, str);
    }

    pub fn print(self: *Text, scene: anytype, text: []const u8) !void {
        if (text.len == 0) return;

        for (self.characters.items) |c| {
            try scene.delete(c.sprite.drawing);
            c.deinit();
        }
        self.characters.clearRetainingCapacity();

        var utf8 = (try std.unicode.Utf8View.init(text)).iterator();

        var start: math.Vec2 = self.transform.translation;

        const space_width: f32 = 10;

        while (utf8.nextCodepoint()) |c| {
            if (c == ' ') {
                start += .{ space_width, 0 };
                continue;
            } else if (c == '\n') {
                start = .{ self.transform.translation[0], start[1] - self.line_spacing };
                continue;
            }

            var char = try Character.init(self.face, c, scene);
            try self.characters.append(char);

            // for now, no word wrapping
            if (char.advance + start[0] > self.bounding_width) {
                start = .{ self.transform.translation[0], start[1] - self.line_spacing };
            }

            char.sprite.transform.translation = start + char.offset;
            char.sprite.updateTransform();
            start += .{ char.advance, 0 };
        }
    }

    pub fn deinit(self: *Text) void {
        for (self.characters.items) |c| {
            c.deinit();
        }
        self.characters.deinit();
    }

    pub fn init(path: [:0]const u8, size: f32, line_spacing: f32, bounding_width: f32) !Text {
        var face = try graphics.ft_lib.createFace(path, 0);
        try face.setCharSize(@intFromFloat(size * 64), 0, 0, 0);
        return .{
            .width = 0,
            .height = 0,
            .bounding_width = bounding_width,
            .face = face,
            .line_spacing = size * line_spacing,
            .characters = std.ArrayList(Character).init(common.allocator),
            .transform = .{
                .scale = .{ 1, 1 },
                .rotation = .{ .angle = 0, .center = .{ 0.5, 0.5 } },
                .translation = .{ 0, 100 },
            },
        };
    }
};
