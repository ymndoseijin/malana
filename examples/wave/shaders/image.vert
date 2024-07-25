#version 450

layout (binding = 0) uniform UBO {
   float zoom;
   vec2 offset;
} ubo;

layout (location = 0) in vec3 pos;
layout (location = 1) in vec2 in_uv;
layout (location = 0) out vec2 out_uv;

void main() {
   gl_Position = vec4(vec3((pos.xy - ubo.offset) / ubo.zoom, 1.0), 1.0);
   out_uv = in_uv;
}
