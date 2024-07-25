#version 450

#define PI 3.14159265359

layout (location = 0) out vec4 out_color;

layout (location = 0) in vec4 in_color;

layout (set = 0, binding = 0) uniform GlobalUBO {
   float time;
   vec2 in_resolution;
} global_ubo;

void main() {
   out_color = vec4(1.0);
}
