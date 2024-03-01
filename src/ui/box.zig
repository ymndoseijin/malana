const std = @import("std");

const math = @import("math");
const Vec2 = math.Vec2;

pub fn nothing(_: *Box, _: *anyopaque) !void {}

pub const Callback = struct {
    fun: *const fn (*Box, *anyopaque) anyerror!void = nothing,
    box: ?*?*Box = null,
    data: *anyopaque = @ptrFromInt(1),
};

const Direction = struct {
    horizontal: bool = false,
    vertical: bool = false,
};

pub const Box = struct {
    label: []const u8,
    expand: Direction,
    flow: Direction,
    fixed_size: Vec2,

    // box will fit children in enabled directions
    fit: Direction,

    // set by parent
    current_size: Vec2,
    absolute_pos: Vec2,

    leaves: std.ArrayList(*Box),
    parent: ?*Box,
    update_callback: std.ArrayList(Callback),

    const BoxInfo = struct {
        expand: Direction = .{},
        flow: Direction = .{},
        fit: Direction = .{},
        size: Vec2 = .{ 0, 0 },
        pos: Vec2 = .{ 0, 0 },
        label: []const u8 = "unnamed",
        parent: ?*Box = null,
        children: []const *Box = &.{},
        callbacks: []const Callback = &.{},
    };

    pub fn print(box: Box, level: usize) void {
        for (0..level) |_| std.debug.print(" ", .{});
        std.debug.print("{{\n", .{});

        for (0..level) |_| std.debug.print(" ", .{});
        std.debug.print(" | label: {s}\n", .{box.label});

        for (0..level) |_| std.debug.print(" ", .{});
        std.debug.print(" | expand: {}\n", .{box.expand});

        for (0..level) |_| std.debug.print(" ", .{});
        std.debug.print(" | size: {d}\n", .{box.current_size});

        for (0..level) |_| std.debug.print(" ", .{});
        std.debug.print(" | fixed size: {d}\n", .{box.fixed_size});

        for (0..level) |_| std.debug.print(" ", .{});
        std.debug.print(" | min: {d}\n", .{box.min()});

        for (0..level) |_| std.debug.print(" ", .{});
        std.debug.print(" | pos: {d}\n", .{box.absolute_pos});

        for (0..level) |_| std.debug.print(" ", .{});
        std.debug.print(" | children: {{\n", .{});

        for (box.leaves.items) |c| {
            c.print(level + 1);
        }

        for (0..level) |_| std.debug.print(" ", .{});
        std.debug.print(" }}\n", .{});

        for (0..level) |_| std.debug.print(" ", .{});
        std.debug.print("}}\n", .{});
    }

    pub fn create(ally: std.mem.Allocator, info: BoxInfo) !*Box {
        var box_arr = try std.ArrayList(*Box).initCapacity(ally, info.children.len);
        for (info.children) |c| try box_arr.append(c);

        var call_arr = try std.ArrayList(Callback).initCapacity(ally, info.callbacks.len);
        for (info.callbacks) |c| try call_arr.append(c);

        const box = try ally.create(Box);
        box.* = .{
            .expand = info.expand,
            .flow = info.flow,
            .fit = info.fit,
            .fixed_size = info.size,
            .current_size = info.size,
            .absolute_pos = info.pos,
            .leaves = box_arr,
            .update_callback = call_arr,
            .parent = info.parent,
            .label = info.label,
        };

        for (info.callbacks) |c| {
            if (c.box) |b| b.* = box;
        }
        for (info.children) |c| c.parent = box;

        return box;
    }

    pub fn deinit(box: Box) void {
        for (box.leaves.items) |b| {
            b.deinit();
        }

        box.leaves.deinit();
    }

    pub fn min(box: Box) Vec2 {
        var val: Vec2 = .{ 0, 0 };
        for (box.leaves.items) |child| {
            const size = child.min();
            if (box.flow.horizontal) {
                val[0] += size[0];
            } else {
                val[0] = @max(val[0], size[0]);
            }

            if (box.flow.vertical) {
                val[1] += size[1];
            } else {
                val[1] = @max(val[1], size[1]);
            }
        }

        val = @max(val, box.fixed_size);
        if (!box.fit.horizontal) val[0] = box.fixed_size[0];
        if (!box.fit.vertical) val[1] = box.fixed_size[1];

        return val;
    }

    pub fn resolve(box: *Box) !void {
        if (box.parent) |parent| {
            if (parent.fit.vertical or parent.fit.horizontal) {
                try parent.resolve();
            } else {
                try box.resolveChildren(true);
            }
        } else {
            try box.resolveChildren(true);
        }
    }

    // called after box size is solved by parent
    pub fn resolveChildren(box: *Box, update_callbacks: bool) !void {
        var expand_count: [2]f32 = .{ 0, 0 };

        if (box.fit.vertical or box.fit.horizontal) {
            const minimal = box.min();
            if (box.fit.horizontal) box.current_size[0] = @max(box.current_size[0], minimal[0]);
            if (box.fit.vertical) box.current_size[1] = @max(box.current_size[1], minimal[1]);
        }

        var free_space = box.current_size;

        for (box.leaves.items) |child| {
            const child_size = child.min();
            if (child.expand.horizontal) {
                expand_count[0] += 1;
            } else if (box.flow.horizontal) {
                free_space[0] -= child_size[0];
            }
            if (child.expand.vertical) {
                expand_count[1] += 1;
            } else if (box.flow.vertical) {
                free_space[1] -= child_size[1];
            }
        }

        var expand_sizes: Vec2 = .{ free_space[0] / expand_count[0], free_space[1] / expand_count[1] };

        var buf: [2048]bool = undefined;
        var seen_indices = buf[0..box.leaves.items.len];
        for (seen_indices) |*b| b.* = false;

        var i: usize = 0;
        while (i < box.leaves.items.len) {
            const child = box.leaves.items[i];
            const child_size = child.min();

            if (seen_indices[i]) {
                i += 1;
                continue;
            }

            if (child.expand.horizontal or child.expand.vertical) {
                if (box.flow.horizontal and child.expand.horizontal and expand_sizes[0] < child_size[0]) {
                    free_space[0] -= child_size[0];
                    expand_count[0] -= 1;
                    expand_sizes[0] = free_space[0] / expand_count[0];
                }
                if (box.flow.vertical and child.expand.vertical and expand_sizes[1] < child_size[1]) {
                    free_space[1] -= child_size[1];
                    expand_count[1] -= 1;
                    expand_sizes[1] = free_space[1] / expand_count[1];
                }

                seen_indices[i] = true;
                i = 0;
                continue;
            }

            i += 1;
        }

        if (!box.flow.vertical) expand_sizes[1] = box.current_size[1];
        if (!box.flow.horizontal) expand_sizes[0] = box.current_size[0];

        var pos = box.absolute_pos;
        for (box.leaves.items) |child| {
            const child_size = child.min();
            child.absolute_pos = pos;

            const actual_w = if (child.expand.horizontal and expand_sizes[0] > child_size[0]) expand_sizes[0] else child_size[0];
            const actual_h = if (child.expand.vertical and expand_sizes[1] > child_size[1]) expand_sizes[1] else child_size[1];

            if (box.flow.horizontal) {
                pos[0] += actual_w;
            }

            child.current_size[0] = actual_w;

            if (box.flow.vertical) {
                pos[1] += actual_h;
            }
            child.current_size[1] = actual_h;

            try child.resolveChildren(update_callbacks);
        }

        if (update_callbacks) {
            for (box.update_callback.items) |callback| {
                try callback.fun(box, callback.data);
            }
        }
    }

    pub fn append(box: *Box, child: Box) !void {
        var new = child;
        new.parent = box;
        try box.leaves.append(new);
    }
};

const MarginInfo = struct {
    top: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,
    right: f32 = 0,
};

pub fn MarginBox(ally: std.mem.Allocator, info: MarginInfo, in_box: *Box) !*Box {
    var box = in_box;
    box.expand = .{ .vertical = true, .horizontal = true };
    box.fixed_size = .{ 0, 0 };

    return try Box.create(ally, .{
        .flow = .{ .horizontal = true },
        .expand = in_box.expand,
        .size = in_box.fixed_size,
        .children = &.{
            try Box.create(ally, .{ .expand = .{ .vertical = true }, .size = .{ info.left, 0 } }),
            try Box.create(ally, .{
                .flow = .{ .vertical = true },
                .expand = .{ .vertical = true, .horizontal = true },
                .children = &.{
                    try Box.create(ally, .{ .expand = .{ .horizontal = true }, .size = .{ 0, info.top } }),
                    box,
                    try Box.create(ally, .{ .expand = .{ .horizontal = true }, .size = .{ 0, info.bottom } }),
                },
            }),
            try Box.create(ally, .{ .expand = .{ .vertical = true }, .size = .{ info.right, 0 } }),
        },
    });
}

test "nice" {
    const test_ally = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(test_ally);
    defer arena.deinit();
    const ally = arena.allocator();

    var root = try Box.create(ally, .{
        .flow = .{ .horizontal = true },
        .size = .{ 0, 0 },
        .fit = .{ .vertical = true },
        .children = &.{
            try Box.create(ally, .{ .expand = .{ .horizontal = true }, .size = .{ 40, 20 } }),
            try Box.create(ally, .{ .expand = .{ .horizontal = true } }),
            try Box.create(ally, .{ .expand = .{ .horizontal = true } }),
        },
    });
    defer root.deinit();
    try root.resolve();

    std.debug.print("{d}\n", .{root.current_size});
}
