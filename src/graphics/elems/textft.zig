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

pub const Image = struct {
    width: u32,
    height: u32,
    data: []img.color.Rgba32,
};

pub const Character = struct {
    image: Image,
    sprite: graphics.Sprite,

    pub fn init(face: freetype.Face, char: u32, scene: anytype) !Character {
        try face.loadChar(char, .{ .render = true });
        const bitmap = face.glyph().bitmap();

        var image: Image = .{
            .data = try common.allocator.alloc(img.color.Rgba32, bitmap.rows() * bitmap.width()),
            .width = bitmap.width(),
            .height = bitmap.rows(),
        };

        for (0..bitmap.rows()) |i| {
            for (0..bitmap.width()) |j| {
                var s: u8 = bitmap.buffer().?[i * bitmap.width() + j];
                image.data[i * image.width + j] = .{ .r = 255, .g = 255, .b = 255, .a = s };
            }
        }

        var draw = try scene.new(.flat);

        return .{
            .image = image,
            .sprite = try graphics.Sprite.initRgba(draw, image),
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

    pub fn updatePos(self: *Text, pos: Vec3) void {
        self.drawing.uniform3f_array[0].value = pos;
    }

    pub fn printFmt(self: *Text, comptime fmt: []const u8, fmt_args: anytype) !void {
        var buf: [4098]u8 = undefined;
        var str = try std.fmt.bufPrint(&buf, fmt, fmt_args);
        try self.print(str);
    }

    pub fn print(self: *Text, text: []const u8, scene: anytype) !void {
        if (text.len == 0) return;
        var utf8 = (try std.unicode.Utf8View.init(text)).iterator();

        var x: f32 = 0;

        while (utf8.nextCodepoint()) |c| {
            if (c == 32) {
                x += 15;
                continue;
            }

            var char = try Character.init(self.face, c, scene);
            try self.characters.append(char);
            char.sprite.transform.translation = .{ x, 0 };
            char.sprite.updateTransform();
            x += @floatFromInt(char.image.width);
        }
    }

    pub fn deinit(self: *Text) void {
        for (self.characters.items) |c| {
            c.deinit();
        }
        self.characters.deinit();
    }

    pub fn initUniform(self: *Text) !void {
        try self.drawing.addUniformVec3("pos", &self.pos);
    }

    pub fn init(path: [:0]const u8) !Text {
        var face = try graphics.ft_lib.createFace(path, 0);
        try face.setCharSize(60 * 48, 0, 50, 0);
        return .{
            .width = 0,
            .height = 0,
            .face = face,
            .characters = std.ArrayList(Character).init(common.allocator),
        };
    }
};
