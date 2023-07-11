const std = @import("std");
const builtin = @import("builtin");

pub var gpa = std.heap.GeneralPurposeAllocator(.{
    .stack_trace_frames = 1000,
}){};
pub const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

const ParseState = enum {
    normal,
    bitmap,
};

const Search = struct { u32, []bool };

pub const BdfParse = struct {
    state: ParseState = .normal,
    map: std.ArrayList(Search),
    width: u32 = 0,

    pub fn init() !BdfParse {
        return BdfParse{ .map = std.ArrayList(Search).init(allocator) };
    }

    pub fn parse(self: *BdfParse, path: [:0]const u8) !void {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var glyph: []bool = undefined;
        var glyph_i: usize = 0;

        var id: u32 = 69420;

        var width: u32 = 0;

        var file_arr = std.ArrayList(u8).init(allocator);
        try in_stream.readAllArrayList(&file_arr, std.math.maxInt(usize));

        var file_it = std.mem.split(u8, file_arr.items, "\n");

        var oweda = [_]bool{false};
        try self.map.append(.{ 69, &oweda });

        while (file_it.next()) |line| {
            switch (self.state) {
                .normal => {
                    if (std.mem.startsWith(u8, line, "BITMAP")) {
                        self.state = .bitmap;
                    } else if (std.mem.startsWith(u8, line, "STARTCHAR")) {
                        var it = std.mem.split(u8, line, "+");
                        _ = it.next();
                        id = try std.fmt.parseInt(u32, it.next().?, 16);
                        //std.debug.print("id: {}\n", .{id});
                    } else if (std.mem.startsWith(u8, line, "FONTBOUNDINGBOX")) {
                        var it = std.mem.split(u8, line, " ");
                        _ = it.next();
                        width = try std.fmt.parseInt(u32, it.next().?, 10);
                        glyph = try allocator.alloc(bool, width * width);
                        //std.debug.print("width: {}\n", .{width});
                    }
                },
                .bitmap => {
                    if (std.mem.startsWith(u8, line, "ENDCHAR")) {
                        self.state = .normal;
                        glyph_i = 0;
                        //std.debug.print("glifo {any}\n", .{res});
                        //std.debug.print("wtf {}\n", .{id});
                        var por_que = Search{ id, try allocator.dupe(bool, glyph) };
                        try self.map.append(por_que);
                        //std.debug.print("{any}\n", .{self.map.items[self.map.items.len - 1]});
                    } else {
                        const val = try std.fmt.parseInt(u32, line, 16);
                        for (0..width) |x| {
                            var i = width - x - 1;
                            glyph[glyph_i] = ((val >> @intCast(i)) & 1) == 1;
                            glyph_i += 1;
                        }
                    }
                },
            }
        }
        self.width = width;
    }

    pub fn getChar(self: *BdfParse, c: u32) ![]bool {
        for (self.map.items) |res| {
            if (res[0] == c) {
                return res[1];
            }
        }
        return error.NoChar;
    }
};

pub fn main() !void {
    var bdf = try BdfParse.init();
    try bdf.parse("b12.bdf");
    std.debug.print("finish {d}\n", .{'a'});
    for (bdf.map.items) |res| {
        if (res[0] == 'a') {
            for (res[1], 0..) |val, i| {
                if (i % bdf.width == 0)
                    std.debug.print("\n", .{});
                if (val) {
                    std.debug.print("#", .{});
                } else {
                    std.debug.print(" ", .{});
                }
            }
        }
    }
}
