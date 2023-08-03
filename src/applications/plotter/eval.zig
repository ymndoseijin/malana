const std = @import("std");

pub fn RuntimeEval(comptime eval_type: type, comptime debug: bool, comptime functions: anytype) type {
    return struct {
        identifiers: std.StringHashMap(eval_type),
        const Self = @This();

        pub fn init(gpa: std.mem.Allocator) Self {
            return Self{
                .identifiers = std.StringHashMap(eval_type).init(gpa),
            };
        }

        pub fn deinit(self: *Self) void {
            self.identifiers.deinit();
        }

        pub fn getSides(self: *Self, ast: std.zig.Ast, node: std.zig.Ast.Node, depth: usize) anyerror![2]eval_type {
            const left_token = ast.nodes.get(node.data.lhs);
            const right_token = ast.nodes.get(node.data.rhs);

            if (left_token.main_token != 0 and right_token.main_token != 0) {
                if (debug) {
                    for (0..depth) |_| std.debug.print("| ", .{});
                    std.debug.print("left_token:\n", .{});
                }
                const lhs = try self.traverse(ast, left_token, node.data.lhs, depth + 1);

                if (debug) {
                    for (0..depth) |_| std.debug.print("| ", .{});
                    std.debug.print("right_token:\n", .{});
                }
                const rhs = try self.traverse(ast, right_token, node.data.rhs, depth + 1);

                return .{ lhs, rhs };
            }
            return error.InvalidSides;
        }

        pub fn traverse(self: *Self, ast: std.zig.Ast, node: std.zig.Ast.Node, node_index: u32, depth: usize) !eval_type {
            if (node.main_token == 0) return error.InvalidNullNode;

            const token = ast.tokens.get(node.main_token);
            const name = ast.tokenSlice(node.main_token);

            if (debug) {
                for (0..depth) |_| std.debug.print("| ", .{});
                std.debug.print("\"{s}\" {} {} {}\n", .{ name, token.tag, node.tag, node.data });
            }

            switch (node.tag) {
                .add => {
                    const sides = try self.getSides(ast, node, depth);
                    return sides[0] + sides[1];
                },
                .mul => {
                    const sides = try self.getSides(ast, node, depth);
                    return sides[0] * sides[1];
                },
                .number_literal => {
                    const num = try std.fmt.parseFloat(eval_type, name);
                    return num;
                },
                .identifier => {
                    if (self.identifiers.get(name)) |val| {
                        return val;
                    }
                    return error.UnknownIdentifier;
                },
                .call, .call_one => {
                    var call_buff: [1]u32 = undefined;
                    const call = ast.fullCall(&call_buff, node_index) orelse return error.InvalidFunction;
                    const fun_params = call.ast.params;
                    const fun_name = ast.tokenSlice(ast.nodes.get(node.data.lhs).main_token);

                    inline for (functions) |pair| {
                        const pair_name = pair[0];
                        const pair_fun = pair[1];
                        const param_count = @typeInfo(@TypeOf(pair_fun)).Fn.params.len;

                        if (std.mem.eql(u8, fun_name, pair_name) and param_count == fun_params.len) {
                            const Args = std.meta.ArgsTuple(@TypeOf(pair_fun));
                            var args: Args = undefined;
                            inline for (&args, 0..) |*arg, i| {
                                arg.* = try self.traverse(ast, ast.nodes.get(fun_params[i]), fun_params[i], depth + 1);
                            }
                            return @call(.always_inline, pair_fun, args);
                        }
                    }

                    return error.UnknownFunction;
                },
                .grouped_expression => return try self.traverse(ast, ast.nodes.get(node.data.lhs), node.data.lhs, depth + 1),
                else => return error.InvalidNode,
            }
        }

        pub fn eval(self: *Self, gpa: std.mem.Allocator, input: [:0]const u8) !eval_type {
            var ast = try std.zig.Ast.parse(gpa, input, .zig);
            defer ast.deinit(gpa);

            var set = std.AutoHashMap(u32, void).init(gpa);
            defer set.deinit();
            try set.put(0, void{});

            var buff: [2]u32 = undefined;
            const container = ast.fullContainerDecl(&buff, 0).?;
            const index = ast.nodes.get(container.ast.members[0]).data.rhs;

            return self.traverse(ast, ast.nodes.get(index), index, 0);
        }
    };
}

test "functions" {
    const ally = std.testing.allocator;
    std.debug.print("\n", .{});

    const Fun = struct {
        pub fn pow(a: f32, b: f32) f32 {
            return std.math.pow(f32, a, b);
        }
        pub fn sin(x: f32) f32 {
            return std.math.sin(x);
        }
    };

    var ctx = RuntimeEval(f32, true, .{ .{ "pow", Fun.pow }, .{ "sin", Fun.sin } }).init(ally);
    defer ctx.deinit();
    try ctx.identifiers.put("x", 2);
    std.debug.print("{}\n", .{try ctx.eval(ally, "const res = 0.2*(pow(x, 3+sin(x))+1);")});
}
