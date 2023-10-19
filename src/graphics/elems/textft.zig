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

const CharacterInfo = struct {
    char: u32,
    index: usize,
    count: usize,
    shaders: ?[2][:0]const u8 = null,
};

pub const Character = struct {
    image: Image,
    sprite: graphics.Sprite,
    offset: math.Vec2,
    advance: f32,
    parent: *Text,

    pub fn setOpacity(self: *Character, opacity: f32) void {
        self.sprite.setOpacity(opacity);
    }

    pub fn init(scene: anytype, parent: *Text, info: CharacterInfo) !Character {
        try parent.face.loadChar(info.char, .{ .render = true });
        const glyph = parent.face.glyph();
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

        var sprite = try graphics.Sprite.init(scene, .{ .rgba = image, .shaders = info.shaders });
        sprite.drawing.shader.setUniformFloat("index", @floatFromInt(info.index)); // stop floating here??
        sprite.drawing.shader.setUniformFloat("count", @floatFromInt(info.count)); // here too

        sprite.drawing.shader.setUniformFloat("opacity", parent.opacity);

        return .{
            .image = image,
            .parent = parent,
            .sprite = sprite,
            .offset = offset,
            .advance = advance / 64,
        };
    }

    pub fn deinit(self: Character) void {
        common.allocator.free(self.image.data);
    }
};

const TextInfo = struct {
    text: []const u8,
    shaders: ?[2][:0]const u8 = null,
};

pub const Text = struct {
    characters: std.ArrayList(Character),
    face: freetype.Face,

    width: f32,
    height: f32,

    line_spacing: f32,
    bounding_width: f32,

    // 2D structure
    transform: graphics.Transform2D,
    opacity: f32,

    count: usize = 0,

    cursor_pos: math.Vec2,
    cursor_index: usize = 0,

    pub fn printFmt(self: *Text, scene: anytype, comptime fmt: []const u8, fmt_args: anytype) !void {
        var buf: [4098]u8 = undefined;
        var str = try std.fmt.bufPrint(&buf, fmt, fmt_args);
        try self.print(scene, .{ .text = str });
    }

    pub fn setOpacity(self: *Text, opacity: f32) void {
        self.opacity = opacity;
        for (self.characters.items) |*c| {
            c.setOpacity(opacity);
        }
    }

    pub fn clear(self: *Text, scene: anytype) !void {
        self.cursor_pos = self.transform.translation;
        self.cursor_index = 0;
        self.count = 0;
        for (self.characters.items) |c| {
            try scene.delete(c.sprite.drawing);
            c.deinit();
        }
        self.characters.clearRetainingCapacity();
    }

    pub fn print(self: *Text, scene: anytype, info: TextInfo) !void {
        if (info.text.len == 0) return;

        const count = blk: {
            var it = (try std.unicode.Utf8View.init(info.text)).iterator();
            var size: usize = 0;
            while (it.nextCodepoint()) |_| size += 1;
            break :blk size + self.count;
        };

        self.count = count;

        var utf8 = (try std.unicode.Utf8View.init(info.text)).iterator();

        var start: math.Vec2 = self.cursor_pos;

        const space_width: f32 = 10;

        while (utf8.nextCodepoint()) |c| {
            defer self.cursor_index += 1;
            if (c == ' ') {
                start += .{ space_width, 0 };
                continue;
            } else if (c == '\n') {
                start = .{ self.transform.translation[0], start[1] - self.line_spacing };
                continue;
            }

            var char = try Character.init(scene, self, .{
                .char = c,
                .shaders = info.shaders,
                .count = count,
                .index = self.cursor_index,
            });
            try self.characters.append(char);

            // for now, no word wrapping
            if (char.advance + start[0] > self.bounding_width) {
                start = .{ self.transform.translation[0], start[1] - self.line_spacing };
            }

            char.sprite.transform.translation = start + char.offset;
            char.sprite.updateTransform();
            start += .{ char.advance, 0 };
        }

        self.cursor_pos = start;
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
            .opacity = 1,
            .bounding_width = bounding_width,
            .face = face,
            .line_spacing = size * line_spacing,
            .characters = std.ArrayList(Character).init(common.allocator),
            .cursor_pos = .{ 0, 100 },
            .transform = .{
                .scale = .{ 1, 1 },
                .rotation = .{ .angle = 0, .center = .{ 0.5, 0.5 } },
                .translation = .{ 0, 100 },
            },
        };
    }
};
