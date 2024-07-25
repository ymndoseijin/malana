#version 450

layout (binding = 0) uniform SpatialUBO {
   float time;
   vec2 in_resolution;
} spatial_ubo;

layout (binding = 1) uniform OtherUBO {
   mat4 transform;
   vec4 color;
} other_ubo;

layout (location = 0) in vec2 uv;
layout (location = 0) out vec4 FragColor;

void main()
{
   FragColor = other_ubo.color;
}
