#version 450

layout (binding = 0) uniform SpatialUBO {
   float time;
   vec2 in_resolution;
} spatial_ubo;

layout (binding = 1) uniform LineUBO {
   vec4 color;
} line_ubo;

layout (location = 0) in vec2 uv;
layout (location = 0) out vec4 frag_color;

void main() {
   frag_color = vec4(1.0);
}
