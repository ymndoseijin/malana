#version 450

layout (binding = 0) uniform SpatialUBO {
   float time;
} spatial_ubo;

layout (binding = 1) uniform OtherUBO {
   vec3 color;
} other_ubo;

layout (location = 0) in vec2 uv;
layout (location = 0) out vec4 FragColor;

layout(binding = 2) uniform sampler2D texSampler;

void main()
{
   FragColor = texture(texSampler, uv);
}
