#version 450

layout (location = 0) out vec4 out_color;

layout (location = 2) in vec3 in_pos;

layout (set = 0, binding = 0) uniform GlobalUBO {
   float time;
   vec2 in_resolution;
} global_ubo;

void main() {
   out_color = vec4(1);
}
