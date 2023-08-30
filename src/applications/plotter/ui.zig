const std = @import("std");
const graphics = @import("graphics");
const Window = graphics.Window;

const math = @import("math");
const Vec2 = math.Vec2;

const Direction = enum {
    Row,
    RowReverse,
    Column,
    ColumnReverse,
};

const BoxState = packed struct {
    expand: Direction,
    layout: Direction,
};

const Box = struct {
    size: Vec2,
    pos: Vec2,

    //state: BoxState,
    children: std.ArrayList(*Box),

    focusable: Focusable,

    pub fn init(allocator: std.mem.Allocator, pos: Vec2, size: Vec2) Box {
        return .{
            .focusable = Focusable{},
            .children = std.ArrayList(*Box).init(allocator),
            .pos = pos,
            .size = size,
        };
    }

    pub fn inside_box(self: Box, pos: Vec2) bool {
        const e_x = self.size[0] + self.pos[0];
        const e_y = self.size[1] + self.pos[1];
        return (self.pos[0] >= pos[0] and pos[0] >= e_x) and (self.size[1] >= pos[1] and pos[1] >= e_y);
    }

    pub fn update(self: *Box) void {
        var offset: f32 = 0;
        for (self.children) |child| {
            try child.update();
            offset += child.getSize(self.state.layout);
        }
    }
};

const Focusable = struct {
    key_func: *const fn (*Window, i32, i32, i32, i32) anyerror!void = defaultKey,
    char_func: *const fn (*Window, u32) anyerror!void = defaultChar,
    frame_func: *const fn (*Window, i32, i32) anyerror!void = defaultFrame,
    scroll_func: *const fn (*Window, f64, f64) anyerror!void = defaultScroll,

    pub fn defaultKey(_: *Window, _: i32, _: i32, _: i32, _: i32) !void {
        return;
    }

    pub fn defaultChar(_: *Window, _: u32) !void {
        return;
    }

    pub fn defaultFrame(_: *Window, _: i32, _: i32) !void {
        return;
    }

    pub fn defaultScroll(_: *Window, _: f64, _: f64) !void {
        return;
    }
};

const Ui = struct {
    focused: ?*Focusable,
    elements: std.ArrayList(*Box),

    pub fn init(allocator: std.mem.Allocator) Ui {
        return .{
            .focused = null,
            .elements = std.ArrayList(*Box).init(allocator),
        };
    }

    pub fn deinit(self: *Ui) void {
        self.elements.deinit();
    }
};

test "focusable" {
    const ally = std.testing.allocator;
    var ui = Ui.init(ally);
    defer ui.deinit();

    var box = Box.init(ally, .{ 0, 0 }, .{ 20, 20 });
    try ui.elements.append(&box);
}
