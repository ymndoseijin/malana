#version 450

layout (location = 0) in vec3 in_pos;
layout (location = 1) in vec4 in_color;

layout (location = 0) out vec4 out_color;

layout (binding = 0) uniform GlobalUBO {
   float time;
   vec2 in_resolution;
} global_ubo;

void main() {
   gl_Position = vec4(in_pos, 1.0);
   out_color = out_color;
}
