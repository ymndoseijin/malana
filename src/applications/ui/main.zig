const std = @import("std");
const graphics = @import("graphics");

const common = @import("common");

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

const AABB = struct {
    size: Vec2,
    pos: Vec2,

    pub fn isInside(self: AABB, pos: Vec2) bool {
        const e_x = self.size[0] + self.pos[0];
        const e_y = self.size[1] + self.pos[1];
        return (self.pos[0] <= pos[0] and pos[0] <= e_x) and (self.pos[1] <= pos[1] and pos[1] <= e_y);
    }
};

const Box = struct {
    //state: BoxState,
    children: std.ArrayList(*Box),

    pub fn init(allocator: std.mem.Allocator, pos: Vec2, size: Vec2) Box {
        return .{
            .children = std.ArrayList(*Box).init(allocator),
            .pos = pos,
            .size = size,
        };
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
    key_func: *const fn (*anyopaque, *Ui, i32, i32, i32, i32) anyerror!void = defaultKey,
    char_func: *const fn (*anyopaque, *Ui, u32) anyerror!void = defaultChar,
    frame_func: *const fn (*anyopaque, *Ui, i32, i32) anyerror!void = defaultFrame,
    scroll_func: *const fn (*anyopaque, *Ui, f64, f64) anyerror!void = defaultScroll,
    mouse_func: *const fn (*anyopaque, *Ui, i32, i32, i32) anyerror!void = defaultMouse,

    focus_enter_func: *const fn (*anyopaque, *Ui, i32, i32, i32) anyerror!void = defaultMouse,
    focus_exit_func: *const fn (*anyopaque, *Ui, i32, i32, i32) anyerror!void = defaultMouse,

    cursor_func: *const fn (*anyopaque, *Ui, f64, f64) anyerror!void = defaultCursor,
    aabb: *AABB,

    pub fn defaultKey(_: *anyopaque, _: *Ui, _: i32, _: i32, _: i32, _: i32) !void {
        return;
    }

    pub fn defaultChar(_: *anyopaque, _: *Ui, _: u32) !void {
        return;
    }

    pub fn defaultFrame(_: *anyopaque, _: *Ui, _: i32, _: i32) !void {
        return;
    }

    pub fn defaultScroll(_: *anyopaque, _: *Ui, _: f64, _: f64) !void {
        return;
    }

    pub fn defaultMouse(_: *anyopaque, _: *Ui, _: i32, _: i32, _: i32) !void {
        return;
    }

    pub fn defaultCursor(_: *anyopaque, _: *Ui, _: f64, _: f64) !void {
        return;
    }
};

const EventType = struct { *anyopaque, Focusable };
const Ui = struct {
    focused: ?EventType,
    elements: std.ArrayList(EventType),
    window: Window,

    pub fn init(allocator: std.mem.Allocator) !*Ui {
        var ui = try allocator.create(Ui);
        ui.* = .{
            .focused = null,
            .elements = std.ArrayList(EventType).init(allocator),
            .window = try Window.initBare(500, 500),
        };

        try ui.window.addToMap(ui);

        ui.window.setKeyCallback(&Ui.getKey);
        ui.window.setCharCallback(&Ui.getChar);
        ui.window.setFrameCallback(&Ui.getFrame);
        ui.window.setScrollCallback(&Ui.getScroll);
        ui.window.setCursorCallback(&Ui.getCursor);
        ui.window.setMouseButtonCallback(&Ui.getMouse);

        return ui;
    }

    pub fn getKey(ptr: *anyopaque, key: i32, scancode: i32, action: i32, mods: i32) !void {
        var ui: *Ui = @ptrCast(@alignCast(ptr));

        if (ui.focused) |focused_elem| {
            try focused_elem[1].key_func(focused_elem[0], ui, key, scancode, action, mods);
        }
    }

    pub fn getChar(ptr: *anyopaque, codepoint: u32) !void {
        var ui: *Ui = @ptrCast(@alignCast(ptr));

        if (ui.focused) |focused_elem| {
            try focused_elem[1].char_func(focused_elem[0], ui, codepoint);
        }
    }

    pub fn getFrame(ptr: *anyopaque, width: i32, height: i32) !void {
        var ui: *Ui = @ptrCast(@alignCast(ptr));

        if (ui.focused) |focused_elem| {
            try focused_elem[1].frame_func(focused_elem[0], ui, width, height);
        }
    }

    pub fn getScroll(ptr: *anyopaque, xoffset: f64, yoffset: f64) !void {
        var ui: *Ui = @ptrCast(@alignCast(ptr));

        if (ui.focused) |focused_elem| {
            try focused_elem[1].scroll_func(focused_elem[0], ui, xoffset, yoffset);
        }
    }

    pub fn getMouse(ptr: *anyopaque, button: i32, action: i32, mods: i32) !void {
        var ui: *Ui = @ptrCast(@alignCast(ptr));

        var pos: [2]f64 = undefined;
        graphics.glfw.glfwGetCursorPos(ui.window.glfw_win, &pos[0], &pos[1]);

        if (button == 0) {
            for (ui.elements.items) |elem| {
                if (ui.focused) |focused_elem| {
                    if (elem[0] == focused_elem[0]) continue;
                }

                if (elem[1].aabb.isInside(.{ @floatCast(pos[0]), @floatCast(pos[1]) })) {
                    if (ui.focused) |focused_elem| {
                        try focused_elem[1].focus_exit_func(focused_elem[0], ui, button, action, mods);
                    }

                    ui.focused = elem;

                    if (ui.focused) |focused_elem| {
                        try focused_elem[1].focus_enter_func(focused_elem[0], ui, button, action, mods);
                    }
                    break;
                }
            }
        }

        if (ui.focused) |focused_elem| {
            if (focused_elem[1].aabb.isInside(.{ @floatCast(pos[0]), @floatCast(pos[1]) })) {
                try focused_elem[1].mouse_func(focused_elem[0], ui, button, action, mods);
            } else {
                try focused_elem[1].focus_exit_func(focused_elem[0], ui, button, action, mods);
                ui.focused = null;
            }
        }
    }

    pub fn getCursor(ptr: *anyopaque, xoffset: f64, yoffset: f64) !void {
        var ui: *Ui = @ptrCast(@alignCast(ptr));

        if (ui.focused) |focused_elem| {
            try focused_elem[1].cursor_func(focused_elem[0], ui, xoffset, yoffset);
        }
    }

    pub fn deinit(self: *Ui) void {
        self.elements.deinit();
    }
};

pub fn focusEnter(_: *anyopaque, _: *Ui, _: i32, _: i32, _: i32) !void {
    std.debug.print("Entered focus!!!!\n", .{});
}

pub fn focusExit(_: *anyopaque, _: *Ui, _: i32, _: i32, _: i32) !void {
    std.debug.print("Left focus!!!!\n", .{});
}

pub fn main() !void {
    defer _ = common.gpa_instance.deinit();

    try graphics.initGraphics();
    defer graphics.deinitGraphics();

    const ally = common.allocator;
    var ui = try Ui.init(ally);
    defer {
        ui.deinit();
        ally.destroy(ui);
    }

    var box = AABB{ .pos = .{ 0, 0 }, .size = .{ 100, 100 } };
    var nothing: ?i32 = null;
    try ui.elements.append(EventType{ &nothing, Focusable{
        .focus_enter_func = focusEnter,
        .focus_exit_func = focusExit,
        .aabb = &box,
    } });

    while (ui.window.alive) {
        graphics.waitGraphicsEvent();
    }
}
