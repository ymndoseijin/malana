// TODO: remove pub
pub const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});

const AREA_SIZE = 512;

const img = @import("img");

const common = @import("common.zig");
const gl = @import("gl.zig");
const std = @import("std");

const math = @import("math.zig");

const Uniform1f = struct {
    name: [:0]const u8,
    value: f32,
};

const Uniform3f = struct {
    name: [:0]const u8,
    value: math.Vec3,
};

const Uniform4fv = struct {
    name: [:0]const u8,
    value: *f32,
};

pub const Shader = struct {
    pub fn compileShader(source: [:0]const u8, shader_type: gl.Enum) !u32 {
        const shader: u32 = gl.createShader(shader_type);
        gl.shaderSource(shader, 1, @ptrCast(&source), null);
        gl.compileShader(shader);
        var response: i32 = 1;
        gl.getShaderiv(shader, gl.COMPILE_STATUS, &response);

        var infoLog: [512]u8 = undefined;
        if (response <= 0) {
            gl.getShaderInfoLog(shader, 512, null, &infoLog[0]);
            std.debug.print("Couldn't compile {s} from source: {s}\n", .{ source, infoLog });
            std.os.exit(255);
        }

        return shader;
    }

    pub fn shaderFromFile(comptime path: [:0]const u8, shader_type: gl.Enum) !u32 {
        return try compileShader(@embedFile(path), shader_type);
    }

    pub fn linkShaders(shaders: []u32) !u32 {
        const shaderProgram: u32 = gl.createProgram();

        for (shaders) |shader| {
            //printf("compiling %lu\n", i);
            //printf("it has id %u\n", *(shader_ptr+i));
            gl.attachShader(shaderProgram, shader);
        }

        gl.linkProgram(shaderProgram);

        var response: i32 = 1;
        gl.getShaderiv(shaderProgram, gl.LINK_STATUS, &response);
        var infoLog: [512]u8 = undefined;
        if (response <= 0) {
            gl.getShaderInfoLog(shaderProgram, 512, null, &infoLog[0]);
            std.debug.print("Couldn't compile from source: {s}\n", .{infoLog});
            std.os.exit(255);
        }

        for (shaders) |shader| {
            gl.deleteShader(shader);
        }

        return shaderProgram;
    }

    pub fn setupShader(comptime vertex_path: [:0]const u8, comptime fragment_path: [:0]const u8) !u32 {
        //printf("Compiling vertex shader at %s and fragment at %s\n", vertex_path, fragment_path);
        const vertex: u32 = try shaderFromFile(vertex_path, gl.VERTEX_SHADER);
        const fragment: u32 = try shaderFromFile(fragment_path, gl.FRAGMENT_SHADER);
        var shaderArray = [2]u32{ fragment, vertex };

        const shader_result: u32 = try linkShaders(&shaderArray);

        //printf("In the end, %i is %s, %i is %s and %i is the link, vertex fragment\n", vertex, vertex_path, fragment, fragment_path, shader_result);

        return shader_result;
    }
};

const RenderType = enum {
    line,
    spatial,
};

const DrawingList = common.FieldArrayList(union(RenderType) {
    line: *Drawing(.line),
    spatial: *Drawing(.spatial),
});

pub const Scene = struct {
    drawing_array: DrawingList,

    pub fn init() !Scene {
        return Scene{
            .drawing_array = try DrawingList.init(common.allocator),
        };
    }

    pub fn deinit(self: *Scene) void {
        inline for (DrawingList.Enums) |field| {
            for (self.drawing_array.array(field).items) |elem| {
                elem.deinit();
                common.allocator.destroy(elem);
            }
        }

        self.drawing_array.deinit(common.allocator);
    }

    pub fn new(self: *Scene, comptime render: RenderType) !*Drawing(render) {
        var val = try common.allocator.create(Drawing(render));
        try self.drawing_array.array(render).append(val);
        return val;
    }

    pub fn draw(self: *Scene, win: Window) !void {
        inline for (DrawingList.Enums) |field| {
            for (self.drawing_array.array(field).items) |*elem| {
                try elem.*.draw(win);
            }
        }
    }
};

pub fn Drawing(comptime drawing_type: RenderType) type {
    return struct {
        vao: u32,
        vbo: u32,
        ebo: u32,
        shader_program: u32,

        uniform1f_array: std.ArrayList(Uniform1f),
        uniform3f_array: std.ArrayList(Uniform3f),
        uniform4fv_array: std.ArrayList(Uniform4fv),

        texture: u32,
        has_texture: bool,

        vert_count: usize,

        transform: math.Mat3,
        transform3d: math.Mat3,

        const Self = @This();
        pub const render_type = drawing_type;

        pub fn init(shader: u32) Self {
            var drawing: Self = undefined;

            drawing.shader_program = shader;

            gl.genVertexArrays(1, &drawing.vao);
            gl.genBuffers(1, &drawing.vbo);
            gl.genBuffers(1, &drawing.ebo);

            drawing.uniform1f_array = std.ArrayList(Uniform1f).init(common.allocator);
            drawing.uniform3f_array = std.ArrayList(Uniform3f).init(common.allocator);
            drawing.uniform4fv_array = std.ArrayList(Uniform4fv).init(common.allocator);
            drawing.has_texture = false;
            drawing.texture = 0;
            drawing.vert_count = 0;
            drawing.transform = math.Mat3.identity();
            drawing.transform3d = math.Mat3.identity();

            return drawing;
        }

        pub fn deinit(self: *Self) void {
            self.uniform1f_array.deinit();
            self.uniform3f_array.deinit();
            self.uniform4fv_array.deinit();
        }

        pub fn textureFromRgba(self: *Self, data: []img.color.Rgba32, width: usize, height: usize) !void {
            gl.genTextures(1, &self.texture);
            gl.bindTexture(gl.TEXTURE_2D, self.texture);

            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.MIRRORED_REPEAT);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

            var flipped: @TypeOf(data) = try common.allocator.dupe(@TypeOf(data[0]), data);
            defer common.allocator.free(flipped);
            for (0..height) |i| {
                for (0..width) |j| {
                    const pix = data[(height - i - 1) * width + j];
                    flipped[i * width + j] = pix;
                }
            }

            gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, @intCast(width), @intCast(height), 0, gl.RGBA, gl.UNSIGNED_BYTE, &flipped[0]);

            //gl.generateMipmap(gl.TEXTURE_2D);

            self.has_texture = true;
        }

        pub fn textureFromPath(self: *Self, path: [:0]const u8) !void {
            var read_image = try img.Image.fromFilePath(common.allocator, path);
            defer read_image.deinit();

            switch (read_image.pixels) {
                .rgba32 => |data| {
                    try self.textureFromRgba(data, read_image.width, read_image.height);
                },
                else => return error.InvalidImage,
            }
        }

        pub fn bindVertex(self: *Self, vertices: []const f32, indices: []const u32) void {
            gl.bindVertexArray(self.vao);

            gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
            gl.bufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(f32) * vertices.len), &vertices[0], gl.STATIC_DRAW);

            gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ebo);
            gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(u32) * indices.len), &indices[0], gl.STATIC_DRAW);

            self.vert_count = indices.len;

            switch (drawing_type) {
                .spatial => {
                    gl.bindVertexArray(self.vao);

                    // pos
                    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @ptrFromInt(0));
                    gl.enableVertexAttribArray(0);

                    // uv
                    gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
                    gl.enableVertexAttribArray(1);

                    // normal
                    gl.vertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @ptrFromInt(5 * @sizeOf(f32)));
                    gl.enableVertexAttribArray(2);
                },
                .line => {
                    gl.bindVertexArray(self.vao);

                    // pos
                    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), @ptrFromInt(0));
                    gl.enableVertexAttribArray(0);

                    // color
                    gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
                    gl.enableVertexAttribArray(1);
                },
            }
        }

        pub fn draw(self: *Self, window: Window) !void {
            gl.useProgram(self.shader_program);
            const time = @as(f32, @floatCast(glfw.glfwGetTime()));
            const now: f32 = 2 * time;
            const arrayUniformLoc: i32 = gl.getUniformLocation(self.shader_program, "transform");
            gl.uniformMatrix3fv(arrayUniformLoc, 1, gl.FALSE, &self.transform.columns[0][0]);

            for (self.uniform4fv_array.items) |uni4fv| {
                const uniform4fv_loc: i32 = gl.getUniformLocation(self.shader_program, uni4fv.name);
                gl.uniformMatrix4fv(uniform4fv_loc, 1, gl.FALSE, uni4fv.value);
            }

            const resolutionLoc: i32 = gl.getUniformLocation(self.shader_program, "in_resolution");
            gl.uniform2f(resolutionLoc, @floatFromInt(window.current_width), @floatFromInt(window.current_height));

            const timeUniformLoc: i32 = gl.getUniformLocation(self.shader_program, "time");
            gl.uniform1f(timeUniformLoc, now);

            for (self.uniform1f_array.items) |uni| {
                const uniform_loc: i32 = gl.getUniformLocation(self.shader_program, uni.name);
                gl.uniform1f(uniform_loc, uni.value);
            }

            for (self.uniform3f_array.items) |uni| {
                const uniform_loc: i32 = gl.getUniformLocation(self.shader_program, uni.name);
                gl.uniform3f(uniform_loc, uni.value[0], uni.value[1], uni.value[2]);
            }

            if (self.has_texture) {
                gl.activeTexture(gl.TEXTURE0);
                gl.bindTexture(gl.TEXTURE_2D, self.texture);

                const textureUniformLoc: i32 = gl.getUniformLocation(self.shader_program, "texture0");
                gl.uniform1i(textureUniformLoc, 0);
            }

            gl.bindVertexArray(self.vao);
            switch (drawing_type) {
                .spatial => {
                    gl.drawElements(gl.TRIANGLES, @intCast(self.vert_count), gl.UNSIGNED_INT, null);
                    gl.bindVertexArray(0);
                    gl.bindVertexArray(1);
                    gl.bindVertexArray(2);
                },
                .line => {
                    gl.drawElements(gl.LINES, @intCast(self.vert_count), gl.UNSIGNED_INT, null);
                    gl.bindVertexArray(0);
                    gl.bindVertexArray(1);
                },
            }
        }
    };
}

var gl_dispatch_table: gl.DispatchTable = undefined;

const GlDispatchTableLoader = struct {
    pub fn getCommandFnPtr(command_name: [:0]const u8) glfw.GLFWglproc {
        const res = glfw.glfwGetProcAddress(command_name);
        //std.debug.print("command: {?} {s}\n", .{ res, command_name });
        return res;
    }

    pub fn extensionSupported(extension_name: [:0]const u8) bool {
        const res = glfw.glfwExtensionSupported(extension_name);
        //std.debug.print("ext: {?} {s}\n", .{ res, extension_name });
        return res;
    }
};

var windowMap: ?std.AutoHashMap(*glfw.GLFWwindow, *Window) = null;

pub fn initGraphics() !void {
    if (glfw.glfwInit() == glfw.GLFW_FALSE) return GlfwError.FailedGlfwInit;

    windowMap = std.AutoHashMap(*glfw.GLFWwindow, *Window).init(common.allocator);

    glfw.glfwWindowHint(glfw.GLFW_SAMPLES, 4); // 4x antialiasing
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 4); // We want OpenGL 3.3
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 6);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE); // We don't want the old OpenGL
}

pub fn deinitGraphics() void {
    windowMap.?.deinit();
}

const GlfwError = error{
    FailedGlfwInit,
    FailedGlfwWindow,
};

pub fn getGlfwKey(win_or: ?*glfw.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    const glfw_win = win_or orelse return;

    if (windowMap.?.get(glfw_win)) |win| {
        if (win.key_func) |fun| {
            fun(win, key, scancode, action, mods) catch {
                @panic("error!");
            };
        }
    }
}

pub fn getFramebufferSize(win_or: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    std.debug.print("olá!\n", .{});

    const glfw_win = win_or orelse return;

    if (windowMap.?.get(glfw_win)) |win| {
        win.current_width = width;
        win.current_height = height;

        gl.viewport(0, 0, width, height);

        if (win.frame_func) |fun| {
            fun(win, width, height) catch {
                @panic("error!");
            };
        }
    }
}

pub fn waitGraphicsEvent() void {
    glfw.glfwPollEvents();
}

pub const Window = struct {
    glfw_win: *glfw.GLFWwindow,
    alive: bool,
    current_width: i32 = 100,
    current_height: i32 = 100,

    key_func: ?*const fn (*Window, i32, i32, i32, i32) anyerror!void,
    frame_func: ?*const fn (*Window, i32, i32) anyerror!void,

    pub fn setKeyCallback(self: *Window, fun: *const fn (*Window, i32, i32, i32, i32) anyerror!void) void {
        self.key_func = fun;
    }

    pub fn setFrameCallback(self: *Window, fun: *const fn (*Window, i32, i32) anyerror!void) void {
        self.frame_func = fun;
    }

    pub fn init(width: i32, height: i32) !*Window {
        const win_or = glfw.glfwCreateWindow(width, height, "My Title", null, null);

        const glfw_win = win_or orelse return GlfwError.FailedGlfwWindow;

        glfw.glfwMakeContextCurrent(glfw_win);
        _ = glfw.glfwSetKeyCallback(glfw_win, getGlfwKey);
        _ = glfw.glfwSetFramebufferSizeCallback(glfw_win, getFramebufferSize);
        //glfw.glfwSetMouseButtonCallback(win, mouse_button_callback);
        //glfw.glfwSetCursorPosCallback(win, cursor_position_callback);

        if (!gl_dispatch_table.init(GlDispatchTableLoader)) return error.GlInitFailed;

        gl.makeDispatchTableCurrent(&gl_dispatch_table);

        gl.enable(gl.BLEND);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.MIRRORED_REPEAT);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);

        var win = try common.allocator.alloc(Window, 1);
        @memset(win, Window{
            .glfw_win = glfw_win,
            .key_func = null,
            .frame_func = null,
            .alive = true,
        });

        try windowMap.?.put(glfw_win, &win[0]);

        return &win[0];
    }

    pub fn deinit(self: *Window) void {
        glfw.glfwDestroyWindow(self.glfw_win);
        gl.makeDispatchTableCurrent(null);
        glfw.glfwTerminate();
        common.allocator.destroy(self);
    }
};
