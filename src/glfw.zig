pub const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

const GlfwError = error{
    FailedGlfwInit,
};

pub fn init() !void {
    if (c.glfwInit() == c.GLFW_FALSE) return GlfwError.FailedGlfwInit;
}

pub fn terminate() void {
    c.glfwTerminate();
}
