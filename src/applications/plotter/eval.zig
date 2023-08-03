const std = @import("std");

pub fn RuntimeEval(comptime eval_type: type, comptime debug: bool) type {
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
                const lhs = try self.traverse(ast, left_token, depth + 1);

                if (debug) {
                    for (0..depth) |_| std.debug.print("| ", .{});
                    std.debug.print("right_token:\n", .{});
                }
                const rhs = try self.traverse(ast, right_token, depth + 1);

                return .{ lhs, rhs };
            }
            return error.InvalidSides;
        }

        pub fn traverse(self: *Self, ast: std.zig.Ast, node: std.zig.Ast.Node, depth: usize) !eval_type {
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

            return self.traverse(ast, ast.nodes.get(index), 0);
        }
    };
}
