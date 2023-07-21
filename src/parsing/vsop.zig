const std = @import("std");
const builtin = @import("builtin");
const math = @import("math");
const common = @import("common");

const geometry = @import("geometry");
const graphics = @import("graphics");

const MeshBuilder = graphics.MeshBuilder;
const Vertex = geometry.Vertex;

const atan2 = std.math.atan2;
const sin = std.math.sin;
const cos = std.math.cos;

const trimLeft = std.mem.trimLeft;

pub fn VsopParse(comptime coord_num: usize) type {
    return struct {
        const TableData = [][][3]f64;

        table: [coord_num]TableData,
        const Self = @This();

        pub fn at(self: *Self, t: f64) [coord_num]f64 {
            var coords: [coord_num]f64 = .{0} ** coord_num;

            inline for (self.table, 0..) |powers, coord_id| {
                for (powers, 0..) |sums, t_num| {
                    var t_pow: f64 = 1;

                    for (0..t_num) |_| {
                        t_pow *= t;
                    }

                    var sum: f64 = 0;

                    for (sums) |elem| {
                        sum += elem[0] * cos(elem[1] + elem[2] * t) * t_pow;
                    }

                    coords[coord_id] += sum;
                }
            }

            return coords;
        }

        pub fn init(path: [:0]const u8) !Self {
            var file = try std.fs.cwd().openFile(path, .{});
            defer file.close();

            var buf_reader = std.io.bufferedReader(file.reader());
            var in_stream = buf_reader.reader();

            var buf: [4096]u8 = undefined;

            var coord_id: usize = 0;
            var t_num: usize = 0;

            var sums = std.ArrayList([3]f64).init(common.allocator);
            defer sums.deinit();
            var factors: [coord_num][10][][3]f64 = undefined;

            var coord_factor: [coord_num]usize = [1]usize{0} ** coord_num;

            var not_start = false;

            while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
                if (std.mem.startsWith(u8, line, " VSOP87")) {
                    if (not_start) {
                        factors[coord_id][t_num] = try sums.toOwnedSlice();
                    } else {
                        not_start = true;
                    }

                    coord_id = try std.fmt.parseInt(usize, trimLeft(u8, line[41..42], " "), 10) - 1;
                    t_num = try std.fmt.parseInt(usize, trimLeft(u8, line[59..60], " "), 10);

                    if (t_num + 1 > coord_factor[coord_id]) coord_factor[coord_id] = t_num + 1;
                } else {
                    const a = try std.fmt.parseFloat(f64, trimLeft(u8, line[79..97], " "));
                    const b = try std.fmt.parseFloat(f64, trimLeft(u8, line[97..111], " "));
                    const c = try std.fmt.parseFloat(f64, trimLeft(u8, line[111..131], " "));
                    try sums.append(.{ a, b, c });
                }
            }

            if (not_start) {
                factors[coord_id][t_num] = try sums.toOwnedSlice();
            }

            var table: [coord_num]TableData = undefined;
            inline for (factors, 0..) |factor, i| {
                table[i] = try common.allocator.dupe([][3]f64, factor[0..coord_factor[i]]);
            }

            return Self{
                .table = table,
            };
        }

        pub fn deinit(self: *Self) void {
            // [][][3]f64;
            inline for (self.table) |factors| {
                for (factors) |sums| {
                    common.allocator.free(sums);
                }
                common.allocator.free(factors);
            }
        }
    };
}

pub fn main() !void {
    const now: f64 = @floatFromInt(std.time.timestamp());
    const time = now / 86400.0 + 2440587.5;
    std.debug.print("{d:.4}\n", .{time});
    //const time = 2456282.5;
    std.debug.print("{d:.4}\n", .{try VsopParse.parse("vsop87/VSOP87C.ven", (time - 2451545.0) / 365250.0, 3)});
}
