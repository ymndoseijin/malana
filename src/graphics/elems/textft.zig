const std = @import("std");
const math = @import("math");
const gl = @import("gl");
const img = @import("img");
const geometry = @import("geometry");
const graphics = @import("../graphics.zig");
const common = @import("common");

const BdfParse = @import("parsing").BdfParse;

const Mesh = geometry.Mesh;
const Vertex = geometry.Vertex;
const HalfEdge = geometry.HalfEdge;

const Drawing = graphics.Drawing;
const glfw = graphics.glfw;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec3Utils = math.Vec3Utils;

const trace = @import("../tracy.zig").trace;

const fs = 15;

const freetype = @import("freetype");

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

const Image = graphics.Texture.Image;

pub const Text = struct {
    characters: std.ArrayList(Character),
    face: freetype.FT_Face,

    width: f32,
    height: f32,

    size: f32,
    line_spacing: f32,
    bounding_width: f32,
    bounding_height: f32,

    wrap: bool,

    // 2D structure
    transform: graphics.Transform2D,
    opacity: f32,

    codepoints: std.ArrayListUnmanaged(u32),
    codepoint_table: std.AutoArrayHashMap(u32, CodepointQuery),

    batch: graphics.CustomSpriteBatch(CharacterUniform),
    scene: *graphics.Scene,

    clear_dirty: bool,
    write_dirty: bool,

    const CodepointQuery = struct {
        metrics: freetype.FT_Glyph_Metrics,
        tex: graphics.Texture,
    };

    const CharacterInfo = struct {
        char: u32,
        index: usize,
        count: usize,
        shaders: ?[]graphics.Shader = null,
    };

    const CharacterUniform: graphics.DataDescription = .{ .T = extern struct {
        transform: [4][4]f32 align(16),
        opacity: f32 align(4),
        index: u32 align(4),
        count: u32 align(4),
        color: [4]f32 align(16),
    } };

    pub const description: graphics.PipelineDescription = .{
        .vertex_description = .{
            .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 } },
        },
        .render_type = .triangle,
        .depth_test = false,
        .depth_write = false,
        .sets = &.{
            .{
                .bindings = &.{
                    .{ .uniform = .{
                        .size = graphics.GlobalUniform.getSize(),
                    } },
                    .{ .uniform = .{
                        .size = CharacterUniform.getSize(),
                        .boundless = true,
                    } },
                },
            },
            .{
                .bindings = &.{
                    .{ .sampler = .{ .boundless = true } },
                },
            },
        },
        .global_ubo = true,
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

        pub fn init(ally: std.mem.Allocator, gpu: graphics.Gpu, parent: *Text, info: CharacterInfo) !Character {
            const tracy = trace(@src());
            defer tracy.end();

            const query: CodepointQuery = blk: {
                const query_trace = trace(@src());
                defer query_trace.end();

                if (parent.codepoint_table.get(info.char)) |known_query| break :blk known_query;
                _ = freetype.FT_Load_Char(parent.face, info.char, freetype.FT_LOAD_RENDER);
                const glyph = parent.face.*.glyph;
                const bitmap = glyph.*.bitmap;

                var image: Image = .{
                    .data = try ally.alloc(graphics.Texture.Rgba32, bitmap.rows * bitmap.width),
                    .width = bitmap.width,
                    .height = bitmap.rows,
                };
                defer ally.free(image.data);

                for (0..bitmap.rows) |i| {
                    for (0..bitmap.width) |j| {
                        const s: u8 = bitmap.buffer[i * bitmap.width + j];
                        image.data[i * image.width + j] = .{ .r = 255, .g = 255, .b = 255, .a = s };
                    }
                }

                var new_tex = try graphics.Texture.init(ally, parent.scene.window, image.width, image.height, .{
                    .mag_filter = .linear,
                    .min_filter = .linear,
                    .texture_type = .flat,
                });
                try new_tex.setFromRgba(ally, gpu, image.data, parent.scene.flip_z);
                try parent.codepoint_table.put(info.char, .{ .tex = new_tex, .metrics = glyph.*.metrics });
                break :blk .{ .tex = new_tex, .metrics = glyph.*.metrics };
            };

            const metrics = query.metrics;
            const tex = query.tex;
            var offset = math.Vec2.init(.{
                @floatFromInt(metrics.horiBearingX),
                @floatFromInt(-metrics.height + metrics.horiBearingY),
            });
            if (!parent.scene.flip_z) offset.val[1] *= -1;

            const metrics_scale: f32 = 1.0 / 64.0;
            offset = offset.scale(metrics_scale);

            const advance: f32 = @floatFromInt(metrics.horiAdvance);

            const default_transform: graphics.Transform2D = .{};

            const sprite = try parent.batch.newSprite(gpu, .{ .tex = tex, .uniform = .{
                .transform = default_transform.getMat().cast(4, 4).columns,
                .opacity = 1.0,
                .index = @intCast(info.index),
                .count = @intCast(info.count),
                .color = .{ 1.0, 1.0, 1.0, 1.0 },
            } });

            return .{
                .parent = parent,
                .sprite = sprite,
                .offset = offset,
                .advance = advance / 64,
                .char = info.char,
                .tex = tex,
            };
        }

        pub fn deinit(character: Character, batch: *graphics.CustomSpriteBatch(CharacterUniform)) !void {
            try character.sprite.delete(batch);
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
        self.clear_dirty = true;
        self.codepoints.clearRetainingCapacity();
    }

    pub fn getExtent(self: Text, unicode: []const u32) !f32 {
        var res: f32 = 0;
        for (unicode) |c| {
            _ = freetype.FT_Load_Char(self.face, c, freetype.FT_LOAD_RENDER);
            const glyph = self.face.*.glyph;
            const metrics = glyph.*.metrics;
            const advance: f32 = @floatFromInt(metrics.horiAdvance);
            res += advance / 64;
        }
        return res;
    }

    pub fn print(text: *Text, ally: std.mem.Allocator, info: PrintInfo) !void {
        if (info.text.len == 0) return;

        text.write_dirty = true;

        var unicode = (try std.unicode.Utf8View.init(info.text)).iterator();

        while (unicode.nextCodepoint()) |c| {
            try text.codepoints.append(ally, c);
        }
    }

    pub fn update(text: *Text, ally: std.mem.Allocator, gpu: graphics.Gpu) !void {
        const tracy = trace(@src());
        defer tracy.end();

        if (text.clear_dirty) {
            text.batch.clear();
            text.characters.clearRetainingCapacity();
            text.clear_dirty = false;
        }

        if (text.codepoints.items.len == 0 or !text.write_dirty) return;

        text.write_dirty = false;

        {
            var index: usize = text.codepoints.items.len - 1;

            for (text.codepoints.items) |c| {
                defer index += 1;
                if (c == '\n' or c == 32) {
                    continue;
                }
                const char = try Character.init(ally, gpu, text, .{
                    .char = c,
                    .count = text.codepoints.items.len,
                    .index = index,
                });
                const color = .{ 1.0, 1.0, 1.0 };
                char.sprite.getUniformOr(&text.batch, 1).?.setAsUniformField(CharacterUniform, .color, .{ color[0], color[1], color[2], 0.0 });
                try text.characters.append(ally, char);
            }
            for (text.characters.items) |char| {
                char.sprite.getUniformOr(&text.batch, 1).?.setAsUniformField(CharacterUniform, .count, @as(u32, @intCast(text.codepoints.items.len)));
            }
        }

        // character layouting

        if (text.characters.items.len == 0) return;
        var start: math.Vec2 = text.transform.translation;
        start.val[1] += text.line_spacing;

        const space_width: f32 = 10;

        var it = std.mem.splitScalar(u32, text.codepoints.items, ' ');

        var character_index: usize = 0;

        var height = text.line_spacing;

        text.width = 0;

        while (it.next()) |word| {
            if (text.wrap and try text.getExtent(word) + start.val[0] > text.bounding_width + text.transform.translation.val[0] and text.codepoints.items.len != 0) {
                if (text.scene.flip_z) {
                    start.val = .{ text.transform.translation.val[0], start.val[1] - text.line_spacing };
                } else {
                    start.val = .{ text.transform.translation.val[0], start.val[1] + text.line_spacing };
                }
                height += text.line_spacing;
            }

            for (word) |c| {
                if (c == '\n') {
                    if (text.scene.flip_z) {
                        start.val = .{ text.transform.translation.val[0], start.val[1] - text.line_spacing };
                    } else {
                        start.val = .{ text.transform.translation.val[0], start.val[1] + text.line_spacing };
                    }
                    height += text.line_spacing;
                    continue;
                }

                var char = &text.characters.items[character_index];

                if (text.wrap and char.advance + start.val[0] > text.bounding_width + text.transform.translation.val[0]) {
                    if (text.scene.flip_z) {
                        start.val = .{ text.transform.translation.val[0], start.val[1] - text.line_spacing };
                    } else {
                        start.val = .{ text.transform.translation.val[0], start.val[1] + text.line_spacing };
                    }
                    height += text.line_spacing;
                }

                if (text.scene.flip_z) {
                    char.sprite.transform.translation = start.add(char.offset);
                } else {
                    char.sprite.transform.translation = start.add(char.offset).sub(.init(.{
                        0,
                        @floatFromInt(char.tex.height),
                    }));
                }
                char.sprite.transform.scale = math.Vec2.init(.{ @floatFromInt(char.tex.width), @floatFromInt(char.tex.height) });
                char.sprite.updateTransform(&text.batch);

                text.width = @max(text.width + char.advance, text.width);
                start.val[0] += char.advance;
                character_index += 1;
            }
            if (it.peek() != null) {
                start.val[0] += space_width;
            }
        }

        text.bounding_height = height;
    }

    pub fn deinit(self: *Text, ally: std.mem.Allocator, gpu: graphics.Gpu) void {
        self.characters.deinit(ally);
        self.codepoints.deinit(ally);
        for (self.codepoint_table.values()) |*v| {
            v.tex.deinit(ally, gpu);
        }
        self.codepoint_table.deinit();
        self.batch.deinit(ally, gpu);
    }

    const TextInfo = struct {
        path: [:0]const u8,
        size: f32,
        line_spacing: f32,
        wrap: bool = true,
        bounding_width: f32 = 0,
        pipeline: ?graphics.RenderPipeline = null,
        scene: *graphics.Scene,
        target: graphics.RenderTarget,
    };

    pub fn init(ally: std.mem.Allocator, info: TextInfo) !Text {
        var face: freetype.FT_Face = undefined;
        _ = freetype.FT_New_Face(graphics.ft_lib, info.path, 0, &face);
        _ = freetype.FT_Set_Char_Size(face, @intFromFloat(info.size * 64), 0, 0, 0);

        return .{
            .width = 0,
            .height = 0,
            .opacity = 1,
            .bounding_width = info.bounding_width,
            .bounding_height = info.size * info.line_spacing,
            .face = face,
            .size = info.size,
            .line_spacing = info.size * info.line_spacing,
            .characters = .empty,
            .codepoints = .empty,
            .codepoint_table = std.AutoArrayHashMap(u32, CodepointQuery).init(ally),
            .batch = try graphics.CustomSpriteBatch(CharacterUniform).init(info.scene, .{
                .pipeline = if (info.pipeline) |p| p else info.scene.default_pipelines.textft,
                .target = info.target,
            }),
            .scene = info.scene,
            .wrap = info.wrap,
            .transform = .{
                .scale = math.Vec2.init(.{ 1, 1 }),
                .rotation = .{ .angle = 0, .center = math.Vec2.init(.{ 0.5, 0.5 }) },
                .translation = math.Vec2.init(.{ 0, 0 }),
            },
            .clear_dirty = false,
            .write_dirty = false,
        };
    }
};
