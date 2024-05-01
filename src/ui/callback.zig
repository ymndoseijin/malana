const std = @import("std");
const graphics = @import("graphics");

const common = @import("common");

const Window = graphics.Window;

const math = @import("math");
const Vec2 = math.Vec2;

pub const Region = struct {
    transform: ?graphics.Transform2D = null,

    pub fn isInside(self: Region, in_pos: [2]f32) bool {
        if (self.transform) |transform| {
            const pos = Vec2.init(in_pos);
            const relative = transform.reverse(pos).val;
            return 0 <= relative[0] and relative[0] <= 1 and 0 <= relative[1] and relative[1] <= 1;
        }

        return true;
    }
};

const DefaultRegion: Region = .{};

const Focusable = struct {
    key_func: *const fn (*anyopaque, *Callback, i32, i32, graphics.Action, i32) anyerror!void = defaultKey,
    char_func: *const fn (*anyopaque, *Callback, u32) anyerror!void = defaultChar,
    frame_func: *const fn (*anyopaque, *Callback, i32, i32) anyerror!void = defaultFrame,
    scroll_func: *const fn (*anyopaque, *Callback, f64, f64) anyerror!void = defaultScroll,
    mouse_func: *const fn (*anyopaque, *Callback, i32, graphics.Action, i32) anyerror!void = defaultMouse,
    cursor_func: *const fn (*anyopaque, *Callback, f64, f64) anyerror!void = defaultCursor,

    focus_enter_func: *const fn (*anyopaque, *Callback) anyerror!bool = defaultFocus,
    focus_exit_func: *const fn (*anyopaque, *Callback) anyerror!void = defaultExit,

    region: *const Region = &DefaultRegion,

    pub fn defaultKey(_: *anyopaque, _: *Callback, _: i32, _: i32, _: graphics.Action, _: i32) !void {
        return;
    }

    pub fn defaultChar(_: *anyopaque, _: *Callback, _: u32) !void {
        return;
    }

    pub fn defaultFrame(_: *anyopaque, _: *Callback, _: i32, _: i32) !void {
        return;
    }

    pub fn defaultScroll(_: *anyopaque, _: *Callback, _: f64, _: f64) !void {
        return;
    }

    pub fn defaultEnter(_: *anyopaque, _: *Callback, _: i32, _: i32, _: i32) !bool {
        return true;
    }

    pub fn defaultMouse(_: *anyopaque, _: *Callback, _: i32, _: graphics.Action, _: i32) !void {}

    pub fn defaultExit(_: *anyopaque, _: *Callback) !void {
        return;
    }

    pub fn defaultCursor(_: *anyopaque, _: *Callback, _: f64, _: f64) !void {
        return;
    }

    pub fn defaultFocus(_: *anyopaque, _: *Callback) !bool {
        return true;
    }
};

const EventType = struct { *anyopaque, Focusable };
pub const Callback = struct {
    focused: ?EventType,
    elements: std.ArrayList(EventType),
    window: *Window,

    pub fn init(allocator: std.mem.Allocator, win: *Window) !Callback {
        return .{
            .window = win,
            .focused = null,
            .elements = std.ArrayList(EventType).init(allocator),
        };
    }

    pub fn getKey(callback: *Callback, key: i32, scancode: i32, action: graphics.Action, mods: i32) !void {
        if (callback.focused) |focused_elem| {
            try focused_elem[1].key_func(focused_elem[0], callback, key, scancode, action, mods);
        }
    }

    pub fn getChar(callback: *Callback, codepoint: u32) !void {
        if (callback.focused) |focused_elem| {
            try focused_elem[1].char_func(focused_elem[0], callback, codepoint);
        }
    }

    pub fn getFrame(callback: *Callback, width: i32, height: i32) !void {
        if (callback.focused) |focused_elem| {
            try focused_elem[1].frame_func(focused_elem[0], callback, width, height);
        }
    }

    pub fn getScroll(callback: *Callback, xoffset: f64, yoffset: f64) !void {
        if (callback.focused) |focused_elem| {
            try focused_elem[1].scroll_func(focused_elem[0], callback, xoffset, yoffset);
        }
    }

    pub fn unfocus(callback: *Callback) !void {
        if (callback.focused) |focused_elem| {
            try focused_elem[1].focus_exit_func(focused_elem[0], callback);
            callback.focused = null;
        }
    }

    pub fn getMouse(callback: *Callback, button: i32, action: graphics.Action, mods: i32) !void {
        var pos: [2]f64 = undefined;
        graphics.glfw.glfwGetCursorPos(callback.window.glfw_win, &pos[0], &pos[1]);

        if (button == 0 and action == .press) {
            for (callback.elements.items) |elem| {
                if (callback.focused) |focused_elem| {
                    if (elem[0] == focused_elem[0]) continue;
                }

                if (elem[1].region.isInside(.{ @floatCast(pos[0]), @floatCast(pos[1]) })) {
                    if (!try elem[1].focus_enter_func(elem[0], callback)) {
                        continue;
                    }

                    if (callback.focused) |focused_elem| {
                        try focused_elem[1].focus_exit_func(focused_elem[0], callback);
                    }

                    callback.focused = elem;
                    break;
                }
            }
            if (callback.focused) |focused_elem| {
                if (!focused_elem[1].region.isInside(.{ @floatCast(pos[0]), @floatCast(pos[1]) })) {
                    try callback.unfocus();
                } else {
                    try focused_elem[1].mouse_func(focused_elem[0], callback, button, action, mods);
                }
            }
        } else {
            if (callback.focused) |focused_elem| {
                try focused_elem[1].mouse_func(focused_elem[0], callback, button, action, mods);
            }
        }
    }

    pub fn getCursor(callback: *Callback, xoffset: f64, yoffset: f64) !void {
        if (callback.focused) |focused_elem| {
            try focused_elem[1].cursor_func(focused_elem[0], callback, xoffset, yoffset);
        }
    }

    pub fn deinit(self: *Callback) void {
        self.elements.deinit();
    }
};
