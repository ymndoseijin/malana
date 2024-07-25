const std = @import("std");
const graphics = @import("graphics");

const common = @import("common");

const Window = graphics.Window;

const math = @import("math");
const Vec2 = math.Vec2;

const AABB = struct {
    size: Vec2,
    pos: Vec2,

    pub fn isInside(self: AABB, pos: Vec2) bool {
        const e_x = self.size[0] + self.pos[0];
        const e_y = self.size[1] + self.pos[1];
        return (self.pos[0] <= pos[0] and pos[0] <= e_x) and (self.pos[1] <= pos[1] and pos[1] <= e_y);
    }
};

const Focusable = struct {
    key_func: *const fn (*anyopaque, *Ui, i32, i32, i32, i32) anyerror!void = defaultKey,
    char_func: *const fn (*anyopaque, *Ui, u32) anyerror!void = defaultChar,
    frame_func: *const fn (*anyopaque, *Ui, i32, i32) anyerror!void = defaultFrame,
    scroll_func: *const fn (*anyopaque, *Ui, f64, f64) anyerror!void = defaultScroll,

    mouse_func: *const fn (*anyopaque, *Ui, i32, i32, i32) anyerror!bool = defaultMouse,
    focus_enter_func: *const fn (*anyopaque, *Ui, i32, i32, i32) anyerror!bool = defaultMouse,
    focus_exit_func: *const fn (*anyopaque, *Ui, i32, i32, i32) anyerror!void = defaultExit,

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

    pub fn defaultMouse(_: *anyopaque, _: *Ui, _: i32, _: i32, _: i32) !bool {
        return true;
    }

    pub fn defaultExit(_: *anyopaque, _: *Ui, _: i32, _: i32, _: i32) !void {
        return;
    }

    pub fn defaultCursor(_: *anyopaque, _: *Ui, _: f64, _: f64) !void {
        return;
    }
};

const EventType = struct { *anyopaque, Focusable };
pub const Ui = struct {
    focused: ?EventType,
    elements: std.ArrayList(EventType),
    window: *Window,

    pub fn init(allocator: std.mem.Allocator, win: *Window) !Ui {
        return .{
            .window = win,
            .focused = null,
            .elements = std.ArrayList(EventType).init(allocator),
        };
    }

    pub fn getKey(ui: *Ui, key: i32, scancode: i32, action: i32, mods: i32) !void {
        if (ui.focused) |focused_elem| {
            try focused_elem[1].key_func(focused_elem[0], ui, key, scancode, action, mods);
        }
    }

    pub fn getChar(ui: *Ui, codepoint: u32) !void {
        if (ui.focused) |focused_elem| {
            try focused_elem[1].char_func(focused_elem[0], ui, codepoint);
        }
    }

    pub fn getFrame(ui: *Ui, width: i32, height: i32) !void {
        if (ui.focused) |focused_elem| {
            try focused_elem[1].frame_func(focused_elem[0], ui, width, height);
        }
    }

    pub fn getScroll(ui: *Ui, xoffset: f64, yoffset: f64) !void {
        if (ui.focused) |focused_elem| {
            try focused_elem[1].scroll_func(focused_elem[0], ui, xoffset, yoffset);
        }
    }

    pub fn getMouse(ui: *Ui, button: i32, action: i32, mods: i32) !void {
        var pos: [2]f64 = undefined;
        graphics.glfw.glfwGetCursorPos(ui.window.glfw_win, &pos[0], &pos[1]);

        if (button == 0) {
            for (ui.elements.items) |elem| {
                if (ui.focused) |focused_elem| {
                    if (elem[0] == focused_elem[0]) continue;
                }

                if (elem[1].aabb.isInside(.{ @floatCast(pos[0]), @floatCast(pos[1]) })) {
                    if (!try elem[1].focus_enter_func(elem[0], ui, button, action, mods)) {
                        continue;
                    }

                    if (ui.focused) |focused_elem| {
                        try focused_elem[1].focus_exit_func(focused_elem[0], ui, button, action, mods);
                    }

                    ui.focused = elem;
                    break;
                }
            }

            if (ui.focused) |focused_elem| {
                if (focused_elem[1].aabb.isInside(.{ @floatCast(pos[0]), @floatCast(pos[1]) })) {
                    if (!try focused_elem[1].mouse_func(focused_elem[0], ui, button, action, mods)) {
                        try focused_elem[1].focus_exit_func(focused_elem[0], ui, button, action, mods);
                        ui.focused = null;
                    }
                } else {
                    try focused_elem[1].focus_exit_func(focused_elem[0], ui, button, action, mods);
                    ui.focused = null;
                }
            }
        }
    }

    pub fn getCursor(ui: *Ui, xoffset: f64, yoffset: f64) !void {
        if (ui.focused) |focused_elem| {
            try focused_elem[1].cursor_func(focused_elem[0], ui, xoffset, yoffset);
        }
    }

    pub fn deinit(self: *Ui) void {
        self.elements.deinit();
    }
};
