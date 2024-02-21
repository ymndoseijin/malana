const std = @import("std");

const math = @import("math");
const Vec2 = math.Vec2;

pub const Callback = struct {
    fun: *const fn (*Box, *anyopaque) anyerror!void,
    data: *anyopaque,
};

const Direction = struct {
    horizontal: bool = false,
    vertical: bool = false,
};

pub const Box = struct {
    expand: Direction,
    flow: Direction,
    fixed_size: Vec2,

    // set by parent
    current_size: Vec2,
    absolute_pos: Vec2,

    leaves: std.ArrayList(Box),
    parent: ?*Box,
    update_callback: std.ArrayList(Callback),

    const BoxInfo = struct {
        expand: Direction = .{},
        flow: Direction = .{},
        size: Vec2 = .{ 0, 0 },
        pos: Vec2 = .{ 0, 0 },
        parent: ?*Box = null,
        children: []const Box = &.{},
        callbacks: []const Callback = &.{},
    };

    pub fn init(ally: std.mem.Allocator, info: BoxInfo) !Box {
        var box_arr = try std.ArrayList(Box).initCapacity(ally, info.children.len);
        for (info.children) |c| try box_arr.append(c);

        var call_arr = try std.ArrayList(Callback).initCapacity(ally, info.callbacks.len);
        for (info.callbacks) |c| try call_arr.append(c);

        return .{
            .expand = info.expand,
            .flow = info.flow,
            .fixed_size = info.size,
            .current_size = info.size,
            .absolute_pos = info.pos,
            .leaves = box_arr,
            .update_callback = call_arr,
            .parent = info.parent,
        };
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
            if (box.flow.horizontal) val[0] += size[0] else val[0] = @max(val[0], size[0]);
            if (box.flow.vertical) val[1] += size[1] else val[1] = @max(val[1], size[1]);
        }

        return @max(val, box.fixed_size);
    }

    // called after box size is solved by parent
    pub fn resolve(box: *Box, ally: std.mem.Allocator) !void {
        var expand_count: [2]f32 = .{ 0, 0 };

        var free_space = box.current_size;

        for (box.leaves.items) |child| {
            const child_size = child.min();
            if (child.expand.horizontal) {
                expand_count[0] += 1;
            } else {
                free_space[0] -= child_size[0];
            }
            if (child.expand.vertical) {
                expand_count[1] += 1;
            } else {
                free_space[1] -= child_size[1];
            }
        }

        var expand_sizes: Vec2 = .{ free_space[0] / expand_count[0], free_space[1] / expand_count[1] };

        var seen_indices = try ally.alloc(bool, box.leaves.items.len);
        for (seen_indices) |*b| b.* = false;
        defer ally.free(seen_indices);

        var i: usize = 0;
        while (i < box.leaves.items.len) {
            const child = box.leaves.items[i];
            const child_size = child.min();

            if (seen_indices[i]) {
                i += 1;
                continue;
            }

            if (child.expand.horizontal or child.expand.vertical) {
                if (child.expand.horizontal and expand_sizes[0] < child_size[0]) {
                    free_space[0] -= child_size[0];
                    expand_count[0] -= 1;
                    expand_sizes[0] = free_space[0] / expand_count[0];
                }
                if (child.expand.vertical and expand_sizes[1] < child_size[1]) {
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
        for (box.leaves.items) |*child| {
            const child_size = child.min();
            child.absolute_pos = pos;

            const actual_w = if (child.expand.horizontal and expand_sizes[0] > child_size[0]) expand_sizes[0] else child_size[0];
            const actual_h = if (child.expand.vertical and expand_sizes[1] > child_size[1]) expand_sizes[1] else child_size[1];

            if (box.flow.horizontal) {
                pos[0] += actual_w;
            } else {
                box.current_size[0] = @max(box.current_size[0], actual_w);
            }

            child.current_size[0] = actual_w;

            if (box.flow.vertical) {
                pos[1] += actual_h;
            } else {
                box.current_size[1] = @max(box.current_size[1], actual_h);
            }
            child.current_size[1] = actual_h;

            try child.resolve(ally);
        }

        for (box.update_callback.items) |callback| {
            try callback.fun(box, callback.data);
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

pub fn MarginBox(ally: std.mem.Allocator, info: MarginInfo, in_box: Box) !Box {
    var box = in_box;
    box.expand = .{ .vertical = true, .horizontal = true };
    box.fixed_size = .{ 0, 0 };

    return try Box.init(ally, .{
        .flow = .{ .horizontal = true },
        .expand = in_box.expand,
        .size = in_box.fixed_size,
        .children = &.{
            try Box.init(ally, .{ .expand = .{ .vertical = true }, .size = .{ info.left, 0 } }),
            try Box.init(ally, .{
                .flow = .{ .vertical = true },
                .expand = .{ .vertical = true, .horizontal = true },
                .children = &.{
                    try Box.init(ally, .{ .expand = .{ .horizontal = true }, .size = .{ 0, info.top } }),
                    box,
                    try Box.init(ally, .{ .expand = .{ .horizontal = true }, .size = .{ 0, info.bottom } }),
                },
            }),
            try Box.init(ally, .{ .expand = .{ .vertical = true }, .size = .{ info.right, 0 } }),
        },
    });
}

test "nice" {
    const ally = std.testing.allocator;
    var root = try Box.init(ally, .{
        .flow = .{ .horizontal = true },
        .size = .{ 100, 100 },
        .children = &.{
            try Box.init(ally, .{ .expand = .{ .horizontal = true }, .size = .{ 40, 20 } }),
            try Box.init(ally, .{ .expand = .{ .horizontal = true } }),
            try Box.init(ally, .{ .expand = .{ .horizontal = true } }),
        },
    });
    defer root.deinit();

    try root.resolve(ally);
}
