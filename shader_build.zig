const std = @import("std");
const Build = std.Build;

const ShaderCompileStep = @This();

/// The directory within the zig-cache directory that is used to store
/// shader artifacts.
pub const cache_dir = "shaders";

/// This structure contains additional options that pertain to specific shaders only.
pub const ShaderOptions = struct {
    /// Additional arguments that should be passed to the shader compiler.
    args: []const []const u8 = &.{},

    /// Paths of additional files that should be watched for changes to
    /// trigger recompilation.
    watched_files: []const []const u8 = &.{},

    /// Adds a preamble to the shader source code, it's inserted after the first line,
    /// where #version is expected.
    preamble: []const u8 = "",

    pub fn hashPath(b: *Build, hasher: anytype, file_path: []const u8) !void {
        const full_path = b.build_root.join(b.allocator, &.{file_path}) catch unreachable;

        const source = std.fs.cwd().readFileAlloc(
            b.allocator,
            full_path,
            std.math.maxInt(usize),
        ) catch |err| switch (err) {
            error.FileNotFound => {
                std.log.err("could not open file '{s}'", .{file_path});
                return error.FileNotFound;
            },
            else => |e| return e,
        };
        hasher.update(source);
    }

    /// To ensure that if compilation options change, the shader is recompiled
    /// properly.
    fn hash(self: ShaderOptions, b: *Build, hasher: anytype) !void {
        for (self.args) |arg| {
            hasher.update(arg);
        }

        for (self.watched_files) |file_path| {
            try hashPath(b, hasher, file_path);
        }
        hasher.update(self.preamble);
    }
};

/// Structure representing a shader to be compiled.
const Shader = struct {
    /// The name of the shader in the generated file.
    /// Must be unique for all shaders added to this ShaderCompileStep.
    name: []const u8,

    /// The path to the shader, relative to the current build root.
    source_path: []const u8,

    /// The final hash of the shader
    hash: [64]u8,

    /// Miscellaneous options to pass when compiling the shader.
    options: ShaderOptions,
};

step: Build.Step,
builder: *Build,

/// The command and optional arguments used to invoke the shader compiler.
compile_command: []const []const u8,

/// The compiler flag used to specify the output path, `-o` most of the time
output_flag: []u8,

/// List of shaders that are to be compiled.
shaders: std.ArrayList(Shader),

/// The main Zig file that contains all the shaders. Each shader is included as
/// `pub const ${name} align(@alignOf(u32))= @embedFile("${path").*;`
generated_file: Build.GeneratedFile,

/// Create a ShaderCompileStep for `builder`. When this step is invoked by the build
/// system, `<compile_command...> <shader_source> <output_flag> <path>` is invoked for each shader.
/// For example, if one calls this with `create(b, "glslc", "-o")` and then
/// `c.addShader("vertex", "vertex.glsl", .{})`, the command will be `glslc vertex.glsl -o <path>`
pub fn create(builder: *Build, compile_command: []const []const u8, output_flag: []const u8) *ShaderCompileStep {
    const self = builder.allocator.create(ShaderCompileStep) catch unreachable;
    self.* = .{
        .builder = builder,
        .step = Build.Step.init(.{
            .id = .custom,
            .name = "shaders",
            .owner = builder,
            .makeFn = make,
        }),
        .compile_command = builder.dupeStrings(compile_command),
        .output_flag = builder.dupe(output_flag),
        .shaders = std.ArrayList(Shader).init(builder.allocator),
        .generated_file = undefined,
    };
    self.generated_file = .{ .step = &self.step };
    return self;
}

/// Returns the shaders module with name.
pub fn getModule(self: *ShaderCompileStep) *Build.Module {
    return self.step.owner.createModule(.{
        .root_source_file = self.getSource(),
    });
}

/// Returns the file source for the generated shader resource code.
pub fn getSource(self: *ShaderCompileStep) Build.LazyPath {
    return .{ .generated = .{ .file = &self.generated_file } };
}

/// Add a shader to be compiled. `src` is shader source path, relative to the project root.
/// Returns the full path where the compiled binary will be stored upon successful compilation.
/// This path can then be used to include the binary into an executable, for example by passing it
/// to @embedFile via an additional generated file.
pub fn add(self: *ShaderCompileStep, name: []const u8, src: []const u8, options: ShaderOptions) void {
    const b = self.step.owner;
    const full_source_path = b.build_root.join(b.allocator, &.{src}) catch unreachable;
    self.shaders.append(.{
        .name = name,
        .source_path = full_source_path,
        .hash = undefined,
        .options = options,
    }) catch unreachable;
}

/// Create a hash of a shader's source contents.
fn hashShaderToFileName(self: *ShaderCompileStep, shader: Shader) ![64]u8 {
    const b = self.step.owner;
    const source = std.fs.cwd().readFileAlloc(
        b.allocator,
        shader.source_path,
        std.math.maxInt(usize),
    ) catch |err| switch (err) {
        error.FileNotFound => {
            std.log.err("could not open shader '{s}'", .{shader.source_path});
            return error.FileNotFound;
        },
        else => |e| return e,
    };

    var hasher = std.crypto.hash.blake2.Blake2b384.init(.{});
    // Random bytes to make ShaderCompileStep unique. Refresh with new random
    // bytes when the implementation is changed in a non-backwards-compatible way.
    hasher.update("Pw7Z*9Q8r!fLY8&!");
    // Make sure that there is no cache hit if the shader's source has changed.
    hasher.update(source);
    // Not only the shader source must be the same to ensure uniqueness -
    // the compilation options must be the same as well!
    try shader.options.hash(b, &hasher);
    // And the compile command, too.
    for (self.compile_command) |cmd| {
        hasher.update(cmd);
    }

    return digest(&hasher);
}

/// Create a base-64 hash digest from a hasher, which we can use as file name.
fn digest(hasher: anytype) [64]u8 {
    var hash_digest: [48]u8 = undefined;
    hasher.final(&hash_digest);
    var hash: [64]u8 = undefined;
    _ = std.fs.base64_encoder.encode(&hash, &hash_digest);
    return hash;
}

/// Internal build function.
fn make(step: *Build.Step, progress: std.Progress.Node) anyerror!void {
    _ = progress;
    const b = step.owner;
    const self: *ShaderCompileStep = @fieldParentPtr("step", step);
    const cwd = std.fs.cwd();

    var cmd = std.ArrayList([]const u8).init(b.allocator);
    try cmd.appendSlice(self.compile_command);
    const base_cmd_len = cmd.items.len;

    var shaders_file_contents = std.ArrayList(u8).init(b.allocator);
    const shaders_out = shaders_file_contents.writer();

    const shaders_dir = try b.cache_root.join(
        b.allocator,
        &.{cache_dir},
    );
    try cwd.makePath(shaders_dir);

    for (self.shaders.items) |*shader| {
        shader.hash = try self.hashShaderToFileName(shader.*);

        const cache_shader_path = try std.fs.path.join(b.allocator, &.{
            shaders_dir,
            &shader.hash,
        });
        try cwd.makePath(cache_shader_path);

        const shader_out_path = try std.fs.path.join(b.allocator, &.{
            cache_shader_path,
            &shader.hash,
        });

        // This path must be relative to the shaders zig file - which is in the same directory
        try shaders_out.print("pub const {s} align(@alignOf(u32)) = @embedFile(\"{s}/{s}\").*;\n", .{
            shader.name,
            &shader.hash,
            &shader.hash,
        });

        // If we have a cache hit, we can save some compile time by not invoking the compile command.
        compile_shader: {
            std.fs.accessAbsolute(shader_out_path, .{}) catch |err| switch (err) {
                error.FileNotFound => break :compile_shader,
                else => |e| return e,
            };

            continue;
        }

        cmd.items.len = base_cmd_len;

        const source_file = try cwd.openFile(shader.source_path, .{});
        const source = try source_file.reader().readAllAlloc(b.allocator, std.math.maxInt(u32));

        const line_idx = std.mem.indexOf(u8, source, "\n").?;

        var preambled_source = std.ArrayList(u8).init(b.allocator);

        try preambled_source.appendSlice(source[0 .. line_idx + 1]);
        try preambled_source.appendSlice("\n");
        try preambled_source.appendSlice(shader.options.preamble);
        try preambled_source.appendSlice("\n");
        try preambled_source.appendSlice(source[line_idx + 1 ..]);

        const preambled_shader_path = try std.fs.path.join(b.allocator, &.{
            cache_shader_path,
            std.fs.path.basename(shader.source_path),
        });

        try cwd.writeFile(.{ .sub_path = preambled_shader_path, .data = preambled_source.items });

        try cmd.appendSlice(shader.options.args);
        try cmd.appendSlice(&.{ preambled_shader_path, self.output_flag, shader_out_path });
        _ = try step.evalChildProcess(cmd.items);
    }

    // Generate a file name for the shaders zig source based on the contents of shaders_file_contents.
    // In this case we don't need to omit writing the file - Zig does this check already for us.
    var hasher = std.crypto.hash.blake2.Blake2b384.init(.{});
    // Note: don't need to seed the hasher - it transitively contains the seed from
    // hashShaderToFileName. Change that if the implementation changes.
    hasher.update(shaders_file_contents.items);

    const shaders_path = try std.fs.path.join(
        b.allocator,
        &.{ shaders_dir, &digest(&hasher) },
    );

    try cwd.writeFile(.{ .sub_path = shaders_path, .data = shaders_file_contents.items });
    self.generated_file.path = shaders_path;
}
