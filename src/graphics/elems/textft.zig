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

pub const Text = struct {
    characters: std.ArrayList(Character),
    face: freetype.Face,

    width: f32,
    height: f32,

    size: f32,
    line_spacing: f32,
    bounding_width: f32,
    bounding_height: f32,

    wrap: bool,
    flip_y: bool,

    // 2D structure
    transform: graphics.Transform2D,
    opacity: f32,

    codepoints: std.ArrayList(u32),
    codepoint_table: std.AutoArrayHashMap(u32, CodepointQuery),

    batch: graphics.CustomSpriteBatch(CharacterUniform),
    scene: *graphics.Scene,

    const CodepointQuery = struct {
        metrics: freetype.GlyphMetrics,
        tex: graphics.Texture,
    };

    const CharacterInfo = struct {
        char: u32,
        index: usize,
        count: usize,
        shaders: ?[]graphics.Shader = null,
    };

    const CharacterUniform: graphics.DataDescription = .{ .T = extern struct {
        transform: math.Mat4,
        opacity: f32,
        index: u32,
        count: u32,
        color: [3]f32 align(4 * 4),
    } };

    pub const description: graphics.PipelineDescription = .{
        .vertex_description = .{
            .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 }, .{ .size = 1, .attribute = .uint } },
        },
        .render_type = .triangle,
        .depth_test = false,
        .uniform_descriptions = &.{ .{
            .size = graphics.GlobalUniform.getSize(),
            .idx = 0,
        }, .{
            .size = CharacterUniform.getSize(),
            .idx = 1,
            .boundless = true,
        } },
        .global_ubo = true,
        .sampler_descriptions = &.{.{
            .idx = 2,
            .boundless = true,
        }},
        .bindless = true,
    };

    pub const Character = struct {
        sprite: graphics.CustomSpriteBatch(CharacterUniform).Sprite,
        offset: math.Vec2,
        advance: f32,
        parent: *Text,
        char: u32,
        tex: graphics.Texture,

        pub fn setOpacity(self: *Character, opacity: f32) void {
            self.sprite.setOpacity(opacity);
        }

        pub fn init(ally: std.mem.Allocator, parent: *Text, info: CharacterInfo) !Character {
            const query: CodepointQuery = blk: {
                if (parent.codepoint_table.get(info.char)) |known_query| break :blk known_query;
                try parent.face.loadChar(info.char, .{ .render = true });
                const glyph = parent.face.glyph();
                const bitmap = glyph.bitmap();

                var image: Image = .{
                    .data = try ally.alloc(img.color.Rgba32, bitmap.rows() * bitmap.width()),
                    .width = bitmap.width(),
                    .height = bitmap.rows(),
                };
                defer ally.free(image.data);

                for (0..bitmap.rows()) |i_in| {
                    for (0..bitmap.width()) |j| {
                        const i = if (parent.flip_y) image.height - i_in - 1 else i_in;
                        const s: u8 = bitmap.buffer().?[i_in * bitmap.width() + j];
                        image.data[i * image.width + j] = .{ .r = 255, .g = 255, .b = 255, .a = s };
                    }
                }

                var new_tex = try graphics.Texture.init(parent.scene.window, image.width, image.height, .{ .mag_filter = .linear, .min_filter = .linear, .texture_type = .flat });
                try new_tex.setFromRgba(image);
                try parent.codepoint_table.put(info.char, .{ .tex = new_tex, .metrics = glyph.metrics() });
                break :blk .{ .tex = new_tex, .metrics = glyph.metrics() };
            };

            const metrics = query.metrics;
            const tex = query.tex;
            var offset = math.Vec2.init(.{ @floatFromInt(metrics.horiBearingX), @floatFromInt(-metrics.height + metrics.horiBearingY) });
            if (!parent.flip_y) offset.val[1] *= -1;

            const metrics_scale: f32 = 1.0 / 64.0;
            offset = offset.scale(metrics_scale);

            const advance: f32 = @floatFromInt(metrics.horiAdvance);

            const sprite = try parent.batch.newSprite(tex);

            sprite.getUniformOr(1).?.setAsUniformField(CharacterUniform, .index, @as(u32, @intCast(info.index)));
            sprite.getUniformOr(1).?.setAsUniformField(CharacterUniform, .count, @as(u32, @intCast(info.count)));
            sprite.getUniformOr(1).?.setAsUniformField(CharacterUniform, .opacity, parent.opacity);

            return .{
                .parent = parent,
                .sprite = sprite,
                .offset = offset,
                .advance = advance / 64,
                .char = info.char,
                .tex = tex,
            };
        }

        pub fn deinit(character: Character) !void {
            try character.sprite.delete();
        }
    };

    const PrintInfo = struct {
        text: []const u8,
        color: [3]f32 = .{ 1.0, 1.0, 1.0 },
    };

    pub fn printFmt(self: *Text, ally: std.mem.Allocator, comptime fmt: []const u8, fmt_args: anytype) !void {
        var buf: [4098]u8 = undefined;
        const str = try std.fmt.bufPrint(&buf, fmt, fmt_args);
        try self.print(ally, .{ .text = str });
    }

    pub fn setOpacity(self: *Text, opacity: f32) void {
        self.opacity = opacity;
        for (self.characters.items) |*c| {
            c.setOpacity(opacity);
        }
    }

    pub fn clear(self: *Text) !void {
        for (self.characters.items) |c| {
            try c.deinit();
        }
        self.characters.clearRetainingCapacity();
        self.codepoints.clearRetainingCapacity();
    }

    pub fn getExtent(self: Text, unicode: []const u32) !f32 {
        var res: f32 = 0;
        for (unicode) |c| {
            try self.face.loadChar(c, .{ .render = true });
            const glyph = self.face.glyph();
            const metrics = glyph.metrics();
            const advance: f32 = @floatFromInt(metrics.horiAdvance);
            res += advance / 64;
        }
        return res;
    }

    pub fn print(self: *Text, ally: std.mem.Allocator, info: PrintInfo) !void {
        if (info.text.len == 0) return;

        var unicode = (try std.unicode.Utf8View.init(info.text)).iterator();

        while (unicode.nextCodepoint()) |c| {
            try self.codepoints.append(c);
        }

        var index: usize = self.codepoints.items.len - 1;

        unicode = (try std.unicode.Utf8View.init(info.text)).iterator();

        while (unicode.nextCodepoint()) |c| {
            defer index += 1;
            if (c == '\n' or c == 32) {
                continue;
            }
            const char = try Character.init(ally, self, .{
                .char = c,
                .count = self.codepoints.items.len,
                .index = index,
            });
            char.sprite.getUniformOr(1).?.setAsUniformField(CharacterUniform, .color, info.color);
            try self.characters.append(char);
        }

        try self.update();

        for (self.characters.items) |c| {
            c.sprite.getUniformOr(1).?.setAsUniformField(CharacterUniform, .count, @as(u32, @intCast(self.codepoints.items.len)));
        }
    }

    pub fn update(self: *Text) !void {
        if (self.characters.items.len == 0) return;
        var start: math.Vec2 = self.transform.translation;
        start.val[1] += self.line_spacing;

        const space_width: f32 = 10;

        var it = std.mem.splitScalar(u32, self.codepoints.items, ' ');

        var character_index: usize = 0;

        var height = self.line_spacing;

        self.width = 0;

        while (it.next()) |word| {
            if (self.wrap and try self.getExtent(word) + start.val[0] > self.bounding_width + self.transform.translation.val[0] and self.codepoints.items.len != 0) {
                start.val = .{ self.transform.translation.val[0], start.val[1] + self.line_spacing };
                height += self.line_spacing;
            }

            for (word) |c| {
                if (c == '\n') {
                    start.val = .{ self.transform.translation.val[0], start.val[1] + self.line_spacing };
                    height += self.line_spacing;
                    continue;
                }

                var char = &self.characters.items[character_index];

                if (self.wrap and char.advance + start.val[0] > self.bounding_width + self.transform.translation.val[0]) {
                    start.val = .{ self.transform.translation.val[0], start.val[1] + self.line_spacing };
                    height += self.line_spacing;
                }

                char.sprite.transform.translation = start.add(char.offset).sub(math.Vec2.init(.{ 0, @floatFromInt(char.tex.height) }));
                char.sprite.transform.scale = math.Vec2.init(.{ @floatFromInt(char.tex.width), @floatFromInt(char.tex.height) });
                char.sprite.updateTransform();
                self.width = @max(self.width + char.advance, self.width);
                start.val[0] += char.advance;
                character_index += 1;
            }
            if (it.peek() != null) {
                start.val[0] += space_width;
            }
        }

        self.bounding_height = height;
    }

    pub fn deinit(self: *Text) void {
        self.characters.deinit();
        self.codepoints.deinit();
        for (self.codepoint_table.values()) |v| {
            v.tex.deinit();
        }
        self.codepoint_table.deinit();
        self.batch.deinit();
    }

    const TextInfo = struct {
        path: [:0]const u8,
        size: f32,
        line_spacing: f32,
        wrap: bool = true,
        flip_y: bool = false,
        bounding_width: f32 = 0,
        pipeline: ?graphics.RenderPipeline = null,
        scene: *graphics.Scene,
    };

    pub fn init(ally: std.mem.Allocator, info: TextInfo) !Text {
        var face = try graphics.ft_lib.createFace(info.path, 0);
        try face.setCharSize(@intFromFloat(info.size * 64), 0, 0, 0);
        return .{
            .width = 0,
            .height = 0,
            .opacity = 1,
            .bounding_width = info.bounding_width,
            .bounding_height = info.size * info.line_spacing,
            .face = face,
            .size = info.size,
            .line_spacing = info.size * info.line_spacing,
            .characters = std.ArrayList(Character).init(ally),
            .codepoints = std.ArrayList(u32).init(ally),
            .codepoint_table = std.AutoArrayHashMap(u32, CodepointQuery).init(ally),
            .batch = try graphics.CustomSpriteBatch(CharacterUniform).init(info.scene, .{
                .pipeline = if (info.pipeline) |p| p else info.scene.default_pipelines.textft,
            }),
            .scene = info.scene,
            .wrap = info.wrap,
            .flip_y = info.flip_y,
            .transform = .{
                .scale = math.Vec2.init(.{ 1, 1 }),
                .rotation = .{ .angle = 0, .center = math.Vec2.init(.{ 0.5, 0.5 }) },
                .translation = math.Vec2.init(.{ 0, 0 }),
            },
        };
    }
};
