#version 450

layout (binding = 0) uniform GlobalUBO {
   float time;
   vec2 in_resolution;
} global_ubo;


layout (location = 0) in vec2 uv;
layout (location = 0) out vec4 FragColor;

void main()
{
   FragColor = vec4(0.0, uv, 1.0);
}
